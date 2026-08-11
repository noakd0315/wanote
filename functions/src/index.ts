import type { Env } from './lib/env';
import type { RateLimitEnv } from './lib/rateLimiter';

// Cloudflare looks for Durable Object classes on the Worker's entrypoint
// module, so the binding in wrangler.toml resolves through this re-export.
export { RateLimiter } from './lib/rateLimiter';

/**
 * Route registry. Each feature agent owns one file under src/routes/ and
 * registers its path here:
 *   - Agent C (medical):  POST /ocr/certificate      -> routes/ocr.ts
 *   - Agent D (ai):       POST /ai/consultation       -> routes/consultation.ts
 *   - Agent D (ai):       POST /ai/report             -> routes/report.ts
 *   - Agent E (billing):  POST /billing/grant-promotional-entitlement
 *                                                     -> routes/grantPromotionalEntitlement.ts
 *   - Agent E (billing):  POST /billing/referral-code  -> routes/referralCode.ts
 *   - Agent E (billing):  POST /billing/apply-pending-grants
 *                                                     -> routes/applyPendingGrants.ts
 *
 * Keep this switch flat and route-file logic self-contained; this file is a
 * likely merge-conflict point between the medical and ai worktrees, so the
 * less logic that lives here, the easier that merge is.
 *
 * NOTE: the Worker's `Env` type (lib/env.ts) doesn't declare the
 * `RATE_LIMITER` Durable Object binding that checkRateLimit() needs, so
 * route handlers widen the type at the call site with `Env & RateLimitEnv`.
 */
// The Flutter web target calls this Worker cross-origin (localhost:5000 ->
// localhost:8787 locally; the deployed app's own origin -> the Worker's
// *.workers.dev origin in production), which makes the browser send a CORS
// preflight OPTIONS request before the real POST. Every response (including
// errors and the preflight itself) needs these headers, or the browser
// blocks the request client-side before it ever reaches a route handler --
// found by manually exercising the food-portion-advice call through a real
// browser session, where it surfaced as the POST never firing at all and
// the OPTIONS preflight 404ing. `*` is fine here since auth is a Bearer
// token (verified per-route via verifyFirebaseToken), not a cookie CORS
// would need to restrict.
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(CORS_HEADERS)) {
    headers.set(key, value);
  }
  return new Response(response.body, { status: response.status, headers });
}

export default {
  async fetch(request: Request, env: Env & RateLimitEnv): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (request.method !== 'POST') {
      return withCors(new Response('Not found', { status: 404 }));
    }

    switch (url.pathname) {
      case '/ocr/certificate': {
        const { handleOcrCertificate } = await import('./routes/ocr');
        return withCors(await handleOcrCertificate(request, env));
      }
      case '/ai/consultation': {
        const { handleConsultation } = await import('./routes/consultation');
        return withCors(await handleConsultation(request, env));
      }
      case '/ai/report': {
        const { handleReport } = await import('./routes/report');
        return withCors(await handleReport(request, env));
      }
      case '/billing/grant-promotional-entitlement': {
        const { handleGrantPromotionalEntitlement } = await import(
          './routes/grantPromotionalEntitlement'
        );
        return withCors(await handleGrantPromotionalEntitlement(request, env));
      }
      case '/billing/referral-code': {
        const { handleReferralCode } = await import('./routes/referralCode');
        return withCors(await handleReferralCode(request, env));
      }
      case '/billing/apply-pending-grants': {
        const { handleApplyPendingGrants } = await import('./routes/applyPendingGrants');
        return withCors(await handleApplyPendingGrants(request, env));
      }
      default:
        return withCors(new Response('Not found', { status: 404 }));
    }
  },
};
