import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { handleGrantPromotionalEntitlement } from '../src/routes/grantPromotionalEntitlement';
import type { FirestoreEnv } from '../src/lib/firestoreClient';
import type { RateLimitEnv } from '../src/lib/rateLimiter';

/**
 * The route this covers is what stops anyone with a free account granting
 * themselves premium: it used to take no request body and grant
 * unconditionally, trusting the Flutter client to have checked that a code
 * was really redeemed.
 *
 * So the tests that matter most are the refusals -- no code, unknown code,
 * spent code, second attempt by the same user -- and the ordering guarantee
 * that the redemption is *recorded* before the entitlement is granted.
 */

const PROJECT_ID = 'demo-wanote';
const EMULATOR = 'firestore.test:8080';
const UID = 'owner-uid';

function base64url(input: string): string {
  return Buffer.from(input, 'utf8').toString('base64url');
}

/** An unsigned JWT shaped like the Firebase Auth Emulator's -- same helper
 * as functions/test/verifyFirebaseToken.test.ts. */
function makeToken(uid: string): string {
  const header = base64url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const body = base64url(
    JSON.stringify({
      iss: `https://securetoken.google.com/${PROJECT_ID}`,
      aud: PROJECT_ID,
      sub: uid,
    }),
  );
  return `${header}.${body}.`;
}

function makeFakeRateLimitKv(): RateLimitEnv['RATE_LIMIT_KV'] {
  const store = new Map<string, string>();
  return {
    get: async (key: string) => store.get(key) ?? null,
    put: async (key: string, value: string) => {
      store.set(key, value);
    },
  } as unknown as RateLimitEnv['RATE_LIMIT_KV'];
}

function makeEnv(overrides: Partial<FirestoreEnv> = {}): FirestoreEnv & RateLimitEnv {
  return {
    ANTHROPIC_API_KEY: '',
    FIREBASE_PROJECT_ID: PROJECT_ID,
    FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
    FIRESTORE_EMULATOR_HOST: EMULATOR,
    REVENUECAT_SECRET_KEY: '',
    RATE_LIMIT_KV: makeFakeRateLimitKv(),
    ...overrides,
  };
}

function makeRequest(body: unknown, token = makeToken(UID)): Request {
  return new Request('https://example.com/billing/grant-promotional-entitlement', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

interface FakeState {
  /** campaign_codes/{id} -> its fields, or absent for "no such code". */
  codes: Map<string, Record<string, unknown>>;
  /** Redemption markers that already exist, as `${uid}/${code}`. */
  markers: Set<string>;
  /** Every committed write, in order, for asserting what was recorded. */
  commits: unknown[][];
  /** Whether RevenueCat was called, and when relative to the commit. */
  revenueCatCalled: boolean;
  revenueCatCalledBeforeCommit: boolean;
}

let state: FakeState;

/** Stands in for the Firestore REST API and RevenueCat. Only the shapes
 * lib/firestoreClient.ts actually sends are handled. */
function installFetchFake(): void {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : (input as Request).url ?? String(input);
    const body = init?.body ? JSON.parse(init.body as string) : {};

    if (url.includes(':beginTransaction')) {
      return new Response(JSON.stringify({ transaction: 'txn-1' }), { status: 200 });
    }

    if (url.includes(':batchGet')) {
      const found = (body.documents as string[]).map((name: string) => {
        const path = name.slice(name.indexOf('/documents/') + '/documents/'.length);
        if (path.startsWith('campaign_codes/')) {
          const id = path.slice('campaign_codes/'.length);
          const fields = state.codes.get(id);
          return fields ? { found: { name, fields } } : { missing: name };
        }
        const [, uid, , code] = path.split('/');
        return state.markers.has(`${uid}/${code}`)
          ? { found: { name, fields: {} } }
          : { missing: name };
      });
      return new Response(JSON.stringify(found), { status: 200 });
    }

    if (url.includes(':commit')) {
      state.commits.push(body.writes as unknown[]);
      return new Response(JSON.stringify({}), { status: 200 });
    }

    if (url.includes(':rollback')) {
      return new Response(JSON.stringify({}), { status: 200 });
    }

    if (url.includes('revenuecat')) {
      state.revenueCatCalled = true;
      state.revenueCatCalledBeforeCommit = state.commits.length === 0;
      return new Response(JSON.stringify({}), { status: 200 });
    }

    throw new Error(`Unexpected fetch in test: ${url}`);
  });
}

describe('handleGrantPromotionalEntitlement', () => {
  beforeEach(() => {
    state = {
      codes: new Map(),
      markers: new Set(),
      commits: [],
      revenueCatCalled: false,
      revenueCatCalledBeforeCommit: false,
    };
    installFetchFake();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  function seedCode(
    id: string,
    { active = true, max = 10, count = 0, referrerUid = null as string | null } = {},
  ): void {
    state.codes.set(id, {
      active: { booleanValue: active },
      maxRedemptions: { integerValue: String(max) },
      redemptionCount: { integerValue: String(count) },
      ...(referrerUid ? { referrerUid: { stringValue: referrerUid } } : {}),
    });
  }

  it('rejects a request with no code -- the old exploit', async () => {
    // This exact request used to return {granted: true}.
    const response = await handleGrantPromotionalEntitlement(makeRequest({}), makeEnv());
    expect(response.status).toBe(400);
    expect(state.revenueCatCalled).toBe(false);
  });

  it('rejects an unauthenticated request', async () => {
    const request = new Request('https://example.com/billing/grant-promotional-entitlement', {
      method: 'POST',
      body: JSON.stringify({ code: 'SUMMER' }),
    });
    const response = await handleGrantPromotionalEntitlement(request, makeEnv());
    expect(response.status).toBe(401);
    expect(state.revenueCatCalled).toBe(false);
  });

  it('rejects a code containing a slash', async () => {
    // A slash would address a different collection entirely.
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: '../users/victim' }),
      makeEnv(),
    );
    expect(response.status).toBe(400);
  });

  it('reports an unknown code without granting', async () => {
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: 'NOPE' }),
      makeEnv(),
    );
    expect(await response.json()).toEqual({ granted: false, reason: 'unknownCode' });
    expect(state.revenueCatCalled).toBe(false);
    expect(state.commits).toHaveLength(0);
  });

  it('reports a spent code without granting', async () => {
    seedCode('SUMMER', { max: 2, count: 2 });
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: 'SUMMER' }),
      makeEnv(),
    );
    expect(await response.json()).toEqual({ granted: false, reason: 'redemptionCapReached' });
    expect(state.revenueCatCalled).toBe(false);
  });

  it('reports a second redemption by the same user without granting', async () => {
    seedCode('SUMMER');
    state.markers.add(`${UID}/SUMMER`);
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: 'SUMMER' }),
      makeEnv(),
    );
    expect(await response.json()).toEqual({ granted: false, reason: 'alreadyRedeemedByUser' });
    expect(state.revenueCatCalled).toBe(false);
  });

  it('refuses to let a user redeem their own referral code', async () => {
    seedCode('REF-OWNER', { referrerUid: UID });
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: 'REF-OWNER' }),
      makeEnv(),
    );
    expect(await response.json()).toEqual({ granted: false, reason: 'selfReferral' });
  });

  it('grants a valid redemption', async () => {
    seedCode('SUMMER');
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: 'SUMMER' }),
      makeEnv(),
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ granted: true });
  });

  it('records the redemption before granting anything', async () => {
    // The other order hands out premium with nothing written if the process
    // dies in between -- which is the unbounded-grant hole this route exists
    // to close.
    seedCode('SUMMER');
    await handleGrantPromotionalEntitlement(
      makeRequest({ code: 'SUMMER' }),
      makeEnv({ REVENUECAT_SECRET_KEY: 'sk-test' }),
    );
    expect(state.revenueCatCalled).toBe(true);
    expect(state.revenueCatCalledBeforeCommit).toBe(false);
  });

  it('writes both the incremented count and the per-user marker', async () => {
    seedCode('SUMMER', { count: 4 });
    await handleGrantPromotionalEntitlement(makeRequest({ code: 'SUMMER' }), makeEnv());

    const writes = state.commits[0] as {
      update: { name: string; fields: Record<string, unknown> };
      updateMask?: { fieldPaths: string[] };
      currentDocument?: { exists: boolean };
    }[];
    expect(writes).toHaveLength(2);

    const counter = writes[0];
    expect(counter.update.fields.redemptionCount).toEqual({ integerValue: '5' });
    // Without the mask a whole-document write would drop referrerUid and the
    // cap, quietly turning a capped code into an unrestricted one.
    expect(counter.updateMask?.fieldPaths).toEqual(['redemptionCount']);
    expect(counter.currentDocument).toEqual({ exists: true });

    const marker = writes[1];
    expect(marker.update.name).toContain(`users/${UID}/redeemed_codes/SUMMER`);
    // exists:false is what makes a concurrent double-redeem fail rather than
    // overwrite.
    expect(marker.currentDocument).toEqual({ exists: false });
  });

  it('normalises the code to upper case', async () => {
    // The UI lets people type in either case; the document id is upper.
    seedCode('SUMMER');
    const response = await handleGrantPromotionalEntitlement(
      makeRequest({ code: ' summer ' }),
      makeEnv(),
    );
    expect(await response.json()).toEqual({ granted: true });
  });
});
