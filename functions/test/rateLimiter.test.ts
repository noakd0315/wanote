import { describe, expect, it } from 'vitest';
import { RateLimiter } from '../src/lib/rateLimiter';

/**
 * This is the only server-side ceiling on what one account can spend of the
 * Anthropic budget, so "roughly enforced" is not good enough.
 *
 * It used to be KV with a read-compare-write and no compare-and-swap. The
 * failure was not theoretical: concurrent requests all read the same count
 * before any write landed, and KV reads are edge-cached for up to a minute,
 * so a burst -- or simply traffic from two regions -- sailed past the limit
 * by multiples. The Durable Object closes that because the check and the
 * increment are one step against strongly consistent storage.
 */

/** Stands in for DurableObjectState.storage, with the alarm API the object
 * uses for cleanup. Deliberately synchronous underneath so the test can
 * exercise interleaving explicitly rather than hoping for it. */
function makeFakeState(): DurableObjectState {
  const map = new Map<string, unknown>();
  // Models Cloudflare's blockConcurrencyWhile: callbacks run one at a time,
  // in arrival order. Without this the fake would interleave and the
  // concurrency test below would fail even against correct code.
  let queue: Promise<unknown> = Promise.resolve();
  return {
    blockConcurrencyWhile: <T>(callback: () => Promise<T>): Promise<T> => {
      const next = queue.then(callback);
      queue = next.catch(() => undefined);
      return next;
    },
    storage: {
      get: async (key: string) => map.get(key),
      put: async (key: string, value: unknown) => {
        map.set(key, value);
      },
      deleteAll: async () => {
        map.clear();
      },
      setAlarm: async () => {},
    },
  } as unknown as DurableObjectState;
}

function checkRequest(maxCalls: number, windowSeconds = 3600): Request {
  return new Request('https://rate-limiter/check', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ maxCalls, windowSeconds }),
  });
}

async function call(limiter: RateLimiter, maxCalls: number) {
  const response = await limiter.fetch(checkRequest(maxCalls));
  return (await response.json()) as { allowed: boolean; remaining: number };
}

describe('RateLimiter', () => {
  it('allows calls up to the limit and refuses the next one', async () => {
    const limiter = new RateLimiter(makeFakeState());

    expect(await call(limiter, 3)).toEqual({ allowed: true, remaining: 2 });
    expect(await call(limiter, 3)).toEqual({ allowed: true, remaining: 1 });
    expect(await call(limiter, 3)).toEqual({ allowed: true, remaining: 0 });
    expect(await call(limiter, 3)).toEqual({ allowed: false, remaining: 0 });
  });

  it('keeps refusing once the limit is reached', async () => {
    const limiter = new RateLimiter(makeFakeState());
    await call(limiter, 1);

    for (let i = 0; i < 5; i++) {
      expect((await call(limiter, 1)).allowed).toBe(false);
    }
  });

  it('counts a burst of concurrent calls exactly once each', async () => {
    // The KV version failed precisely here: ten simultaneous requests each
    // read count=0 and each allowed itself through.
    const limiter = new RateLimiter(makeFakeState());

    const results = await Promise.all(
      Array.from({ length: 10 }, () => call(limiter, 3)),
    );
    const allowed = results.filter((r) => r.allowed).length;

    expect(allowed).toBe(3);
  });

  it('starts a fresh window once the old one lapses', async () => {
    const limiter = new RateLimiter(makeFakeState());
    // A zero-length window is already over by the time the next call lands.
    await limiter.fetch(checkRequest(1, 0));

    const second = await limiter.fetch(checkRequest(1, 0));
    expect(((await second.json()) as { allowed: boolean }).allowed).toBe(true);
  });

  it('clears its storage when the window alarm fires', async () => {
    // Otherwise every user who ever hit a route leaves a row behind forever.
    const state = makeFakeState();
    const limiter = new RateLimiter(state);
    await call(limiter, 1);
    expect((await call(limiter, 1)).allowed).toBe(false);

    await limiter.alarm();

    expect((await call(limiter, 1)).allowed).toBe(true);
  });
});
