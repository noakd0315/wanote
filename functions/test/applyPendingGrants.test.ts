import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { handleApplyPendingGrants } from '../src/routes/applyPendingGrants';
import type { FirestoreEnv } from '../src/lib/firestoreClient';
import type { RateLimitEnv } from '../src/lib/rateLimiter';

/**
 * Rewards earned while the user already had premium are recorded rather than
 * granted, because a promotional entitlement handed to an active subscriber
 * overlaps their paid plan and expires unnoticed. This route delivers them
 * once the plan lapses.
 *
 * The load-bearing test here is the refusal: the client asks for this when it
 * *thinks* premium has ended, and if that were taken at face value a
 * subscriber could stack free months on top of the plan they are paying for.
 */

const PROJECT_ID = 'demo-wanote';
const UID = 'owner-uid';

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

/** In-memory stand-in for the RATE_LIMITER Durable Object namespace: one
 * counter per key, incremented in the same call that checks it -- which is
 * the property the real Durable Object provides and KV did not. */
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
    // A real key, so hasActiveEntitlement() actually calls RevenueCat rather
    // than taking the local-dev "not subscribed" shortcut.
    REVENUECAT_SECRET_KEY: 'sk-test',
    RATE_LIMITER: makeFakeRateLimiter(),
  };
}

function makeRequest(): Request {
  return new Request('https://example.com/billing/apply-pending-grants', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeToken(UID)}` },
  });
}

interface Pending {
  id: string;
  createdAt: string;
  expiresAt: string;
  appliedAt?: string;
}

let pending: Pending[];
let premiumActive: boolean;
let grantCalls: number;
let markedApplied: string[];

function installFetchFake(): void {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : (input as Request).url ?? String(input);

    if (url.includes('api.revenuecat.com') && url.includes('/promotional')) {
      grantCalls += 1;
      return new Response(JSON.stringify({}), { status: 200 });
    }
    if (url.includes('api.revenuecat.com')) {
      return new Response(
        JSON.stringify({
          subscriber: {
            entitlements: premiumActive
              ? { premium: { expires_date: '2099-01-01T00:00:00Z' } }
              : {},
          },
        }),
        { status: 200 },
      );
    }
    if (url.includes('/documents/users/') && (init?.method ?? 'GET') === 'GET') {
      return new Response(
        JSON.stringify({
          documents: pending.map((p) => ({
            name: `projects/${PROJECT_ID}/databases/(default)/documents/users/${UID}/pending_grants/${p.id}`,
            fields: {
              reason: { stringValue: 'referral' },
              createdAt: { timestampValue: p.createdAt },
              expiresAt: { timestampValue: p.expiresAt },
              ...(p.appliedAt ? { appliedAt: { timestampValue: p.appliedAt } } : {}),
            },
          })),
        }),
        { status: 200 },
      );
    }
    if (url.includes(':commit')) {
      const body = JSON.parse(init!.body as string) as {
        writes: { update: { name: string } }[];
      };
      markedApplied.push(body.writes[0].update.name.split('/').pop()!);
      return new Response(JSON.stringify({}), { status: 200 });
    }
    throw new Error(`Unexpected fetch in test: ${url}`);
  });
}

const future = '2099-01-01T00:00:00.000Z';
const past = '2020-01-01T00:00:00.000Z';

describe('handleApplyPendingGrants', () => {
  beforeEach(() => {
    pending = [];
    premiumActive = false;
    grantCalls = 0;
    markedApplied = [];
    installFetchFake();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('refuses to apply anything while the subscription is still active', async () => {
    // The client's claim that premium lapsed is a hint. Believing it would
    // let a subscriber stack free months onto the plan they already pay for.
    premiumActive = true;
    pending = [{ id: 'g1', createdAt: past, expiresAt: future }];

    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());

    expect(await response.json()).toEqual({ applied: 0, reason: 'stillSubscribed' });
    expect(grantCalls).toBe(0);
    expect(markedApplied).toEqual([]);
  });

  it('rejects an unauthenticated request', async () => {
    const request = new Request('https://example.com/billing/apply-pending-grants', {
      method: 'POST',
    });
    const response = await handleApplyPendingGrants(request, makeEnv());
    expect(response.status).toBe(401);
    expect(grantCalls).toBe(0);
  });

  it('applies a pending grant once premium has lapsed', async () => {
    pending = [{ id: 'g1', createdAt: past, expiresAt: future }];

    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());

    expect(await response.json()).toEqual({ applied: 1 });
    expect(grantCalls).toBe(1);
    expect(markedApplied).toEqual(['g1']);
  });

  it('applies several accumulated grants, oldest first', async () => {
    // PM decision: they accumulate. Oldest first so that if anything fails
    // partway, the reward owed longest is the one already delivered.
    pending = [
      { id: 'newer', createdAt: '2026-06-01T00:00:00.000Z', expiresAt: future },
      { id: 'older', createdAt: '2026-01-01T00:00:00.000Z', expiresAt: future },
    ];

    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());

    expect(await response.json()).toEqual({ applied: 2 });
    expect(markedApplied).toEqual(['older', 'newer']);
  });

  it('skips a grant that has already been applied', async () => {
    // Otherwise every launch after a lapse would hand out another month.
    pending = [{ id: 'g1', createdAt: past, expiresAt: future, appliedAt: past }];

    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());

    expect(await response.json()).toEqual({ applied: 0 });
    expect(grantCalls).toBe(0);
  });

  it('skips a grant past its expiry', async () => {
    // PM decision: pending rewards are good for a year.
    pending = [{ id: 'g1', createdAt: past, expiresAt: past }];

    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());

    expect(await response.json()).toEqual({ applied: 0 });
    expect(grantCalls).toBe(0);
    expect(markedApplied).toEqual([]);
  });

  it('applies only the live grants when some have expired', async () => {
    pending = [
      { id: 'stale', createdAt: past, expiresAt: past },
      { id: 'live', createdAt: past, expiresAt: future },
    ];

    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());

    expect(await response.json()).toEqual({ applied: 1 });
    expect(markedApplied).toEqual(['live']);
  });

  it('does nothing when there is nothing owed', async () => {
    const response = await handleApplyPendingGrants(makeRequest(), makeEnv());
    expect(await response.json()).toEqual({ applied: 0 });
    expect(grantCalls).toBe(0);
  });
});
