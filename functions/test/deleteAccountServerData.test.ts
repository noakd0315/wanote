import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { handleDeleteAccountServerData } from '../src/routes/deleteAccountServerData';
import type { FirestoreEnv } from '../src/lib/firestoreClient';
import type { RateLimitEnv } from '../src/lib/rateLimiter';

/**
 * Account deletion's server-side half.
 *
 * The collections this route clears exist *because* clients are not trusted
 * with them (firestore.rules denies clients even a read of `rewards`,
 * `pending_grants` and `redeemed_codes`, and closes `campaign_codes`
 * entirely). That makes them exactly the data that would quietly survive
 * "delete my account" if this route did nothing -- so the tests are mostly
 * about what actually gets deleted, and about the one thing that must not.
 */

const PROJECT_ID = 'demo-wanote';
const UID = 'owner-uid';
/** deriveReferralCode('owner-uid') -- first 8 chars, uppercased. */
const OWN_CODE = 'REF-OWNER-UI';

function makeToken(uid: string): string {
  const b64 = (v: string) => Buffer.from(v, 'utf8').toString('base64url');
  const header = b64(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const body = b64(
    JSON.stringify({
      iss: `https://securetoken.google.com/${PROJECT_ID}`,
      aud: PROJECT_ID,
      sub: uid,
    }),
  );
  return `${header}.${body}.`;
}

function makeFakeRateLimiter(): RateLimitEnv['RATE_LIMITER'] {
  const counts = new Map<string, number>();
  return {
    idFromName: (name: string) => name,
    get: (name: string) => ({
      fetch: async (_url: string, init: RequestInit) => {
        const { maxCalls } = JSON.parse(init.body as string) as { maxCalls: number };
        const used = counts.get(name) ?? 0;
        if (used >= maxCalls) {
          return Response.json({ allowed: false, remaining: 0 });
        }
        counts.set(name, used + 1);
        return Response.json({ allowed: true, remaining: maxCalls - used - 1 });
      },
    }),
  } as unknown as RateLimitEnv['RATE_LIMITER'];
}

function makeEnv(): FirestoreEnv & RateLimitEnv {
  return {
    ANTHROPIC_API_KEY: '',
    FIREBASE_PROJECT_ID: PROJECT_ID,
    FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
    FIRESTORE_EMULATOR_HOST: 'firestore.test:8080',
    REVENUECAT_SECRET_KEY: 'sk-test',
    RATE_LIMITER: makeFakeRateLimiter(),
  };
}

function makeRequest(uid = UID): Request {
  return new Request('https://example.com/account/delete-server-data', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeToken(uid)}` },
  });
}

const docPrefix = `projects/${PROJECT_ID}/databases/(default)/documents`;

/** Contents of the server-owned collections, keyed by collection name. */
let collections: Record<string, string[]>;
/** `referrerUid` per existing `campaign_codes/{code}` document. */
let campaignCodeOwners: Record<string, string>;
/** Document paths (relative to the database root) the route deleted. */
let deleted: string[];
/** RevenueCat app_user_ids the route asked to delete. */
let revenueCatDeletes: string[];
/** What RevenueCat's DELETE responds with. */
let revenueCatStatus: number;

function installFetchFake(): void {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : ((input as Request).url ?? String(input));

    if (url.includes('api.revenuecat.com')) {
      revenueCatDeletes.push(decodeURIComponent(url.split('/subscribers/')[1]));
      return new Response('{}', { status: revenueCatStatus });
    }

    if (url.includes(':batchGet')) {
      const { documents } = JSON.parse(init!.body as string) as { documents: string[] };
      return Response.json(
        documents.map((name) => {
          const code = name.split('/').pop()!;
          const owner = campaignCodeOwners[code];
          return owner === undefined
            ? { missing: name }
            : { found: { name, fields: { referrerUid: { stringValue: owner } } } };
        }),
      );
    }

    if (url.includes(':commit')) {
      const body = JSON.parse(init!.body as string) as { writes: { delete: string }[] };
      for (const write of body.writes) {
        deleted.push(write.delete.slice(`${docPrefix}/`.length));
      }
      return Response.json({});
    }

    // listDocuments: GET /documents/users/{uid}/{collection}
    const match = /\/documents\/users\/[^/]+\/([^?]+)/.exec(url);
    if (match && (init?.method ?? 'GET') === 'GET') {
      const collection = match[1];
      const ids = collections[collection] ?? [];
      return Response.json({
        documents: ids.map((id) => ({
          name: `${docPrefix}/users/${UID}/${collection}/${id}`,
          fields: {},
        })),
      });
    }

    throw new Error(`Unexpected fetch in test: ${url}`);
  });
}

describe('handleDeleteAccountServerData', () => {
  beforeEach(() => {
    collections = {};
    campaignCodeOwners = {};
    deleted = [];
    revenueCatDeletes = [];
    revenueCatStatus = 200;
    installFetchFake();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('deletes every server-owned document belonging to the caller', async () => {
    collections = {
      rewards: ['referral_counter'],
      pending_grants: ['grant-1', 'grant-2'],
      redeemed_codes: ['SUMMER2026'],
    };
    campaignCodeOwners = { [OWN_CODE]: UID };

    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(response.status).toBe(200);
    expect(deleted).toEqual([
      `users/${UID}/rewards/referral_counter`,
      `users/${UID}/pending_grants/grant-1`,
      `users/${UID}/pending_grants/grant-2`,
      `users/${UID}/redeemed_codes/SUMMER2026`,
      `campaign_codes/${OWN_CODE}`,
    ]);
    expect(await response.json()).toEqual({ deleted: 5 });
  });

  it('leaves a referral code owned by someone else alone', async () => {
    // deriveReferralCode() only uses the first eight characters of the uid,
    // so two accounts can derive the same code and the first one to ask owns
    // the document. Deleting it unconditionally would let the second account
    // destroy the first one's referral code just by deleting itself.
    campaignCodeOwners = { [OWN_CODE]: 'a-different-uid' };

    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(response.status).toBe(200);
    expect(deleted).toEqual([]);
  });

  it('deletes the fallback code of a user who lost the race for the first', async () => {
    // The other half of the collision: this user's own code is the `-2` one,
    // and sweeping only the primary candidate would leave it behind with
    // their uid in it.
    campaignCodeOwners = {
      [OWN_CODE]: 'a-different-uid',
      [`${OWN_CODE}-2`]: UID,
    };

    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(deleted).toEqual([`campaign_codes/${OWN_CODE}-2`]);
    expect(response.status).toBe(200);
  });

  it('deletes the RevenueCat subscriber record too', async () => {
    // RevenueCat is keyed by the same uid and holds the purchase history.
    // The privacy policy names it as a processor, so leaving the record
    // there would make "everything is deleted" untrue.
    await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(revenueCatDeletes).toEqual([UID]);
  });

  it('deletes nothing at all when RevenueCat fails', async () => {
    // Deletion is retryable by design; a half-done sweep that reported
    // success would not be.
    collections = { rewards: ['referral_counter'] };
    revenueCatStatus = 500;

    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(response.status).toBe(502);
    expect(deleted).toEqual([]);
  });

  it('treats an already-deleted RevenueCat subscriber as done', async () => {
    // What a retry after a partial failure looks like from RevenueCat's side.
    revenueCatStatus = 404;

    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(response.status).toBe(200);
  });

  it('succeeds on an account that has nothing stored server-side', async () => {
    // The common case: most users never redeem a code or earn a reward.
    // Deletion must not fail for them.
    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deleted: 0 });
    expect(deleted).toEqual([]);
  });

  it('is safe to retry after a partial failure', async () => {
    collections = { pending_grants: ['grant-1'] };

    await handleDeleteAccountServerData(makeRequest(), makeEnv());
    // Second run against a store that is now empty -- what a client retrying
    // a half-finished deletion actually does.
    collections = {};
    deleted = [];
    const response = await handleDeleteAccountServerData(makeRequest(), makeEnv());

    expect(response.status).toBe(200);
    expect(deleted).toEqual([]);
  });

  it('rejects a request with no ID token', async () => {
    const response = await handleDeleteAccountServerData(
      new Request('https://example.com/account/delete-server-data', { method: 'POST' }),
      makeEnv(),
    );

    expect(response.status).toBe(401);
    expect(deleted).toEqual([]);
  });

  it("only ever deletes the caller's own uid, never one named in the request", async () => {
    // There is no request body by design: the uid comes from the verified
    // token, so a caller cannot name someone else's account.
    collections = { rewards: ['referral_counter'] };

    await handleDeleteAccountServerData(makeRequest('someone-else'), makeEnv());

    expect(deleted.every((path) => path.startsWith('users/someone-else/'))).toBe(true);
  });
});
