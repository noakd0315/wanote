import { afterEach, describe, expect, it, vi } from 'vitest';
import { grantPromotionalEntitlement } from '../src/lib/revenueCatClient';
import type { Env } from '../src/lib/env';

function makeEnv(secretKey: string): Env {
  return {
    ANTHROPIC_API_KEY: '',
    FIREBASE_PROJECT_ID: 'demo-wanote',
    REVENUECAT_SECRET_KEY: secretKey,
  };
}

describe('grantPromotionalEntitlement mock fallback (no REVENUECAT_SECRET_KEY configured)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns a mock granted result and never calls fetch when the key is unset', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const result = await grantPromotionalEntitlement({
      env: makeEnv(''),
      appUserId: 'uid-123',
      entitlementIdentifier: 'premium',
      duration: 'monthly',
    });

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(result).toEqual({ granted: true, mock: true });
  });

  it('treats a whitespace-only key as missing too', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const result = await grantPromotionalEntitlement({
      env: makeEnv('   '),
      appUserId: 'uid-123',
      entitlementIdentifier: 'premium',
      duration: 'monthly',
    });

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(result.mock).toBe(true);
  });

  it('logs a warning so the mock path is visible server-side', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

    await grantPromotionalEntitlement({
      env: makeEnv(''),
      appUserId: 'uid-123',
      entitlementIdentifier: 'premium',
      duration: 'monthly',
    });

    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toContain('REVENUECAT_SECRET_KEY is not set');
  });
});

describe('grantPromotionalEntitlement real call (REVENUECAT_SECRET_KEY configured)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('POSTs to the documented promotional-entitlement URL with the right auth header and body shape', async () => {
    const fetchSpy = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response(null, { status: 200 }));

    const result = await grantPromotionalEntitlement({
      env: makeEnv('sk-real-key'),
      appUserId: 'uid-123',
      entitlementIdentifier: 'premium',
      duration: 'monthly',
    });

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0];
    expect(url).toBe(
      'https://api.revenuecat.com/v1/subscribers/uid-123/entitlements/premium/promotional',
    );
    expect(init?.method).toBe('POST');
    const headers = init?.headers as Record<string, string>;
    expect(headers['authorization']).toBe('Bearer sk-real-key');
    expect(headers['content-type']).toBe('application/json');
    expect(JSON.parse(init?.body as string)).toEqual({ duration: 'monthly' });

    expect(result).toEqual({ granted: true, mock: false });
  });

  it('url-encodes the app user id and entitlement identifier', async () => {
    const fetchSpy = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response(null, { status: 200 }));

    await grantPromotionalEntitlement({
      env: makeEnv('sk-real-key'),
      appUserId: 'uid with spaces',
      entitlementIdentifier: 'premium',
      duration: 'monthly',
    });

    const [url] = fetchSpy.mock.calls[0];
    expect(url).toBe(
      'https://api.revenuecat.com/v1/subscribers/uid%20with%20spaces/entitlements/premium/promotional',
    );
  });

  it('throws when RevenueCat returns a non-2xx response', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response('nope', { status: 404 }),
    );

    await expect(
      grantPromotionalEntitlement({
        env: makeEnv('sk-real-key'),
        appUserId: 'uid-123',
        entitlementIdentifier: 'premium',
        duration: 'monthly',
      }),
    ).rejects.toThrow('RevenueCat API error 404');
  });
});
