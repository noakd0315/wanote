import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { handleOcrCertificate } from '../src/routes/ocr';
import type { Env } from '../src/lib/env';
import type { RateLimitEnv } from '../src/lib/rateLimiter';

/**
 * The OCR route forwards whatever image it is given straight to the Anthropic
 * API, so its input validation is a cost control, not just tidiness: the
 * client compresses images before sending, but anyone can call this route
 * directly with a curl command and a Firebase token.
 *
 * It also used to relay Anthropic's raw error body to the caller, which
 * carries upstream request ids and quota state.
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

function makeEnv(overrides: Partial<Env> = {}): Env & RateLimitEnv {
  return {
    ANTHROPIC_API_KEY: '',
    FIREBASE_PROJECT_ID: PROJECT_ID,
    FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
    RATE_LIMITER: makeFakeRateLimiter(),
    ...overrides,
  };
}

function makeRequest(body: unknown): Request {
  return new Request('https://example.com/ocr/certificate', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${makeToken('owner-uid')}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

describe('handleOcrCertificate', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('rejects an oversized image before spending anything', async () => {
    // Previously bounded only by the Worker's 100MB request limit, ten times
    // a day, every byte of it forwarded to a paid API.
    let upstreamCalled = false;
    vi.stubGlobal('fetch', async () => {
      upstreamCalled = true;
      return new Response('{}', { status: 200 });
    });

    const response = await handleOcrCertificate(
      makeRequest({
        image_base64: 'A'.repeat(7_400_000),
        media_type: 'image/jpeg',
      }),
      makeEnv(),
    );

    expect(response.status).toBe(413);
    expect(upstreamCalled).toBe(false);
  });

  it('accepts an image within the cap', async () => {
    const response = await handleOcrCertificate(
      makeRequest({ image_base64: 'A'.repeat(1000), media_type: 'image/jpeg' }),
      // No ANTHROPIC_API_KEY, so callClaude returns its mock response rather
      // than calling out.
      makeEnv(),
    );
    expect(response.status).toBe(200);
  });

  it('rejects an empty image', async () => {
    const response = await handleOcrCertificate(
      makeRequest({ image_base64: '', media_type: 'image/jpeg' }),
      makeEnv(),
    );
    expect(response.status).toBe(400);
  });

  it('rejects an unsupported media type', async () => {
    const response = await handleOcrCertificate(
      makeRequest({ image_base64: 'AAAA', media_type: 'application/pdf' }),
      makeEnv(),
    );
    expect(response.status).toBe(400);
  });

  it('does not relay the upstream error body to the caller', async () => {
    // callClaude throws with the Anthropic response body attached: request
    // ids, model names, quota and billing state. None of that is the
    // caller's business.
    vi.stubGlobal(
      'fetch',
      async () =>
        new Response(
          JSON.stringify({
            error: { message: 'quota exhausted for org org_secret_12345' },
          }),
          { status: 429 },
        ),
    );
    vi.spyOn(console, 'error').mockImplementation(() => {});

    const response = await handleOcrCertificate(
      makeRequest({ image_base64: 'AAAA', media_type: 'image/jpeg' }),
      makeEnv({ ANTHROPIC_API_KEY: 'sk-test' }),
    );

    expect(response.status).toBe(502);
    const text = await response.text();
    expect(text).not.toContain('org_secret_12345');
    expect(text).not.toContain('quota');
    // Still logged, so the detail is not simply lost.
    expect(console.error).toHaveBeenCalled();
  });

  it('rejects an unauthenticated request', async () => {
    const request = new Request('https://example.com/ocr/certificate', {
      method: 'POST',
      body: JSON.stringify({ image_base64: 'AAAA', media_type: 'image/jpeg' }),
    });
    const response = await handleOcrCertificate(request, makeEnv());
    expect(response.status).toBe(401);
  });
});
