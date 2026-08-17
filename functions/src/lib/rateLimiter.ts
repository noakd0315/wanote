/**
 * Per-user rate limiting, backed by a Durable Object.
 *
 * This is the only server-side ceiling on what a single account can spend of
 * the Anthropic budget, and on how fast it can probe campaign codes, so it
 * has to actually hold.
 *
 * It previously used KV with a read-compare-write and no compare-and-swap.
 * Two things compounded: concurrent requests all read the same count before
 * any write landed, and KV reads are cached per edge location for up to a
 * minute with writes propagating globally on roughly the same timescale. A
 * client firing fifty requests at once -- or simply from more than one region
 * -- saw a stale count every time and sailed past the limit by multiples.
 *
 * A Durable Object fixes both properly: requests for a given key are routed
 * to one instance, which handles them one at a time against strongly
 * consistent storage. The check and the increment are the same operation.
 */

export interface RateLimitEnv {
  /** See wrangler.toml's [[durable_objects.bindings]]. */
  RATE_LIMITER: DurableObjectNamespace;
}

export interface RateLimitOptions {
  maxCalls: number;
  windowSeconds: number;
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
}

/** At most [maxCalls] per [key] within [windowSeconds]. */
export async function checkRateLimit(
  env: RateLimitEnv,
  key: string,
  options: RateLimitOptions,
): Promise<RateLimitResult> {
  // idFromName maps a key to a single Durable Object deterministically, so
  // every request for one uid meets the same counter.
  const id = env.RATE_LIMITER.idFromName(`ratelimit:${key}`);
  const stub = env.RATE_LIMITER.get(id);
  const response = await stub.fetch('https://rate-limiter/check', {
    method: 'POST',
    headers: { 'content-type': 'application/json; charset=utf-8' },
    body: JSON.stringify(options),
  });
  return (await response.json()) as RateLimitResult;
}

interface StoredWindow {
  count: number;
  resetAtMs: number;
}

/**
 * The Durable Object itself. Registered in wrangler.toml and re-exported from
 * index.ts, which is where Cloudflare looks for it.
 *
 * Fixed-window rather than sliding: a caller can bunch requests across a
 * window boundary and briefly exceed the nominal rate. That is a known and
 * acceptable property here -- the point is a hard ceiling on sustained use,
 * not smooth pacing, and a sliding window would mean storing every timestamp.
 */
export class RateLimiter {
  constructor(private readonly state: DurableObjectState) {}

  async fetch(request: Request): Promise<Response> {
    const { maxCalls, windowSeconds } = (await request.json()) as RateLimitOptions;

    // blockConcurrencyWhile, not a bare read-then-write. The read and the
    // write are separated by an await, and without exclusivity two requests
    // arriving together both resume holding the same stale count and both
    // allow themselves through -- which is the exact shape of the bug this
    // replaced. Cloudflare's input gating would probably cover it, but
    // depending on that nuance is not worth it when the primitive that
    // states the guarantee outright costs one line.
    const result = await this.state.blockConcurrencyWhile(async () => {
      const now = Date.now();
      const stored = await this.state.storage.get<StoredWindow>('window');
      const window: StoredWindow =
        stored && stored.resetAtMs > now
          ? stored
          : { count: 0, resetAtMs: now + windowSeconds * 1000 };

      if (window.count >= maxCalls) {
        return { allowed: false, remaining: 0 };
      }

      window.count += 1;
      await this.state.storage.put('window', window);
      // Lets the object's storage be reclaimed once the window lapses,
      // instead of keeping a row per user forever.
      await this.state.storage.setAlarm(window.resetAtMs);

      return { allowed: true, remaining: maxCalls - window.count };
    });

    return Response.json(result);
  }

  /** Fires when the window lapses; clears the counter. */
  async alarm(): Promise<void> {
    await this.state.storage.deleteAll();
  }
}
