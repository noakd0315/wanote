/** Cloudflare KV binding used for per-user rate limiting. Add to
 * wrangler.toml as:
 *   [[kv_namespaces]]
 *   binding = "RATE_LIMIT_KV"
 *   id = "<created via `wrangler kv namespace create RATE_LIMIT_KV`>"
 */
export interface RateLimitEnv {
  RATE_LIMIT_KV: KVNamespace;
}

/** Sliding-window-ish limiter: at most [maxCalls] per [uid] within
 * [windowSeconds]. Shared by any route that calls the Anthropic API
 * (OCR, consultation) so a single abusive client can't run up the bill —
 * see spec section 9's "乱用対策". */
export async function checkRateLimit(
  env: RateLimitEnv,
  key: string,
  { maxCalls, windowSeconds }: { maxCalls: number; windowSeconds: number },
): Promise<{ allowed: boolean; remaining: number }> {
  const kvKey = `ratelimit:${key}`;
  const raw = await env.RATE_LIMIT_KV.get(kvKey);
  const count = raw ? parseInt(raw, 10) : 0;

  if (count >= maxCalls) {
    return { allowed: false, remaining: 0 };
  }

  await env.RATE_LIMIT_KV.put(kvKey, String(count + 1), {
    expirationTtl: windowSeconds,
  });
  return { allowed: true, remaining: maxCalls - count - 1 };
}
