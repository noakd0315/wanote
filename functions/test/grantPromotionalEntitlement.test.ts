import { afterEach, describe, expect, it, vi } from 'vitest';
import { handleGrantPromotionalEntitlement } from '../src/routes/grantPromotionalEntitlement';
import type { Env } from '../src/lib/env';
import type { RateLimitEnv } from '../src/lib/rateLimiter';

const PROJECT_ID = 'demo-wanote';

function base64url(input: string): string {
  return Buffer.from(input, 'utf8').toString('base64url');
}

/** Builds an unsigned JWT shaped like what the Firebase Auth Emulator
 * issues -- same helper as functions/test/verifyFirebaseToken.test.ts. */
function makeEmulatorToken(payload: Record<string, unknown>): string {
  const header = base64url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const body = base64url(JSON.stringify(payload));
  return `${header}.${body}.`;
}

function makeToken(uid: string): string {
  return makeEmulatorToken({
    iss: `https://securetoken.google.com/${PROJECT_ID}`,
    aud: PROJECT_ID,
    sub: uid,
  });
}

/** Minimal in-memory stand-in for the Cloudflare KV binding
 * checkRateLimit() uses -- only implements the subset it calls (get/put). */
function makeFakeRateLimitKv(): RateLimitEnv['RATE_LIMIT_KV'] {
  const store = new Map<string, string>();
  return {
    get: async (key: string) => store.get(key) ?? null,
    put: async (key: string, value: string) => {
      store.set(key, value);
    },
  } as unknown as RateLimitEnv['RATE_LIMIT_KV'];
}

function makeEnv(overrides: Partial<Env> = {}): Env & RateLimitEnv {
  return {
    ANTHROPIC_API_KEY: '',
    FIREBASE_PROJECT_ID: PROJECT_ID,
    FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
    REVENUECAT_SECRET_KEY: '',
    RATE_LIMIT_KV: makeFakeRateLimitKv(),
    ...overrides,
  };
}

function makeRequest(token?: string): Request {
  return new Request('https://example.com/billing/grant-promotional-entitlement', {
    method: 'POST',
    headers: token ? { authorization: `Bearer ${token}` } : undefined,
  });
}

describe('handleGrantPromotionalEntitlement', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns 401 when the Authorization header is missing', async () => {
    const response = await handleGrantPromotionalEntitlement(makeRequest(), makeEnv());
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: 'Unauthorized.' });
  });

  it('returns 401 when the token is invalid', async () => {
    const response = await handleGrantPromotionalEntitlement(
      makeRequest('not-a-real-token'),
      makeEnv(),
    );
    expect(response.status).toBe(401);
  });

  it('grants via the mock fallback when REVENUECAT_SECRET_KEY is unset, returning {granted: true}', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const response = await handleGrantPromotionalEntitlement(
      makeRequest(makeToken('user-1')),
      makeEnv({ REVENUECAT_SECRET_KEY: '' }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ granted: true });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('calls the real RevenueCat API and returns {granted: true} when a secret key is configured', async () => {
    const fetchSpy = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response(null, { status: 200 }));

    const response = await handleGrantPromotionalEntitlement(
      makeRequest(makeToken('user-1')),
      makeEnv({ REVENUECAT_SECRET_KEY: 'sk-real-key' }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ granted: true });
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url] = fetchSpy.mock.calls[0];
    expect(url).toBe(
      'https://api.revenuecat.com/v1/subscribers/user-1/entitlements/premium/promotional',
    );
  });

  it('returns 502 when the RevenueCat call fails', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('boom', { status: 500 }));

    const response = await handleGrantPromotionalEntitlement(
      makeRequest(makeToken('user-1')),
      makeEnv({ REVENUECAT_SECRET_KEY: 'sk-real-key' }),
    );

    expect(response.status).toBe(502);
  });

  it('rate-limits after 5 calls per day for the same uid', async () => {
    const env = makeEnv({ REVENUECAT_SECRET_KEY: '' });
    const token = makeToken('user-rate-limited');

    for (let i = 0; i < 5; i++) {
      const response = await handleGrantPromotionalEntitlement(makeRequest(token), env);
      expect(response.status).toBe(200);
    }

    const sixthResponse = await handleGrantPromotionalEntitlement(makeRequest(token), env);
    expect(sixthResponse.status).toBe(429);
  });

  it('rate limits are tracked per-uid, not globally', async () => {
    const env = makeEnv({ REVENUECAT_SECRET_KEY: '' });

    for (let i = 0; i < 5; i++) {
      const response = await handleGrantPromotionalEntitlement(
        makeRequest(makeToken('user-a')),
        env,
      );
      expect(response.status).toBe(200);
    }

    const otherUserResponse = await handleGrantPromotionalEntitlement(
      makeRequest(makeToken('user-b')),
      env,
    );
    expect(otherUserResponse.status).toBe(200);
  });
});
