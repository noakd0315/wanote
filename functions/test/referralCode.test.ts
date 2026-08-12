import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { handleReferralCode, referralCodeCandidates } from '../src/routes/referralCode';
import type { FirestoreEnv } from '../src/lib/firestoreClient';
import type { RateLimitEnv } from '../src/lib/rateLimiter';

/**
 * Referral code allocation, and the collision it used to get wrong.
 *
 * deriveReferralCode() takes the first eight characters of the uid and
 * upper-cases them, so two accounts can derive the same code. The old code
 * read "this document already exists" as "then it is yours" -- which is true
 * almost always, and catastrophic when it isn't: the second user's referral
 * code was really the first user's, so everyone they invited credited a
 * stranger and their own counter never moved. Nothing errored.
 */

const PROJECT_ID = 'demo-wanote';

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
  return {
    idFromName: (name: string) => name,
    get: () => ({
      fetch: async () => Response.json({ allowed: true, remaining: 10 }),
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

function makeRequest(uid: string): Request {
  return new Request('https://example.com/billing/referral-code', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeToken(uid)}` },
  });
}

/** Existing `campaign_codes` documents: code -> referrerUid. */
let existing: Record<string, string>;
/** Codes the route successfully created, in order. */
let created: string[];

function installFetchFake(): void {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : ((input as Request).url ?? String(input));

    if (url.includes(':commit')) {
      const body = JSON.parse(init!.body as string) as {
        writes: {
          update: { name: string; fields: { referrerUid: { stringValue: string } } };
        }[];
      };
      const write = body.writes[0];
      const code = write.update.name.split('/').pop()!;
      if (existing[code] !== undefined) {
        // What Firestore returns when `currentDocument.exists: false` fails.
        return new Response('FAILED_PRECONDITION: document already exists', { status: 400 });
      }
      existing[code] = write.update.fields.referrerUid.stringValue;
      created.push(code);
      return Response.json({});
    }

    if (url.includes(':batchGet')) {
      const { documents } = JSON.parse(init!.body as string) as { documents: string[] };
      return Response.json(
        documents.map((name) => {
          const code = name.split('/').pop()!;
          return existing[code] === undefined
            ? { missing: name }
            : {
                found: { name, fields: { referrerUid: { stringValue: existing[code] } } },
              };
        }),
      );
    }

    throw new Error(`Unexpected fetch in test: ${url}`);
  });
}

describe('handleReferralCode', () => {
  beforeEach(() => {
    existing = {};
    created = [];
    installFetchFake();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  const code = async (uid: string) => {
    const response = await handleReferralCode(makeRequest(uid), makeEnv());
    expect(response.status).toBe(200);
    return ((await response.json()) as { code: string }).code;
  };

  it('creates the code derived from the uid', async () => {
    expect(await code('abcdefgh1111')).toBe('REF-ABCDEFGH');
    expect(created).toEqual(['REF-ABCDEFGH']);
  });

  it('returns the same code on every later call, creating nothing new', async () => {
    const first = await code('abcdefgh1111');
    created = [];

    expect(await code('abcdefgh1111')).toBe(first);
    expect(created).toEqual([]);
  });

  it('gives a colliding uid its own code rather than someone else’s', async () => {
    // The bug. These two uids differ, but their first eight characters
    // upper-case to the same string -- Firebase uids are case-sensitive.
    const owner = await code('abcdefgh1111');
    const other = await code('ABCDEFGH2222');

    expect(owner).toBe('REF-ABCDEFGH');
    expect(other).toBe('REF-ABCDEFGH-2');
    expect(other).not.toBe(owner);
  });

  it('never reassigns a code that already belongs to someone', async () => {
    await code('abcdefgh1111');
    await code('ABCDEFGH2222');

    // Whoever asks, the first owner keeps theirs.
    expect(existing['REF-ABCDEFGH']).toBe('abcdefgh1111');
    expect(existing['REF-ABCDEFGH-2']).toBe('ABCDEFGH2222');
  });

  it('keeps handing the fallback owner their fallback code', async () => {
    await code('abcdefgh1111');
    const second = await code('ABCDEFGH2222');
    created = [];

    expect(await code('ABCDEFGH2222')).toBe(second);
    expect(created).toEqual([]);
  });

  it('gives up rather than hand out a stranger’s code', async () => {
    // Statistically unreachable, but the loop is bounded and the bound has
    // to fail closed: handing back a code owned by someone else is the exact
    // failure this whole mechanism exists to prevent.
    for (const candidate of referralCodeCandidates('abcdefgh1111')) {
      existing[candidate] = 'somebody-else';
    }

    const response = await handleReferralCode(makeRequest('abcdefgh1111'), makeEnv());

    expect(response.status).toBe(502);
  });

  it('rejects a request with no ID token', async () => {
    const response = await handleReferralCode(
      new Request('https://example.com/billing/referral-code', { method: 'POST' }),
      makeEnv(),
    );

    expect(response.status).toBe(401);
    expect(created).toEqual([]);
  });
});
