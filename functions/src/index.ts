import type { Env } from './lib/env';
import type { RateLimitEnv } from './lib/rateLimiter';

/**
 * Route registry. Each feature agent owns one file under src/routes/ and
 * registers its path here:
 *   - Agent C (medical):  POST /ocr/certificate      -> routes/ocr.ts
 *   - Agent D (ai):       POST /ai/consultation       -> routes/consultation.ts
 *   - Agent D (ai):       POST /ai/report             -> routes/report.ts
 *
 * Keep this switch flat and route-file logic self-contained; this file is a
 * likely merge-conflict point between the medical and ai worktrees, so the
 * less logic that lives here, the easier that merge is.
 *
 * NOTE (Agent C / medical): the Worker's `Env` type (lib/env.ts) doesn't
 * declare the `RATE_LIMIT_KV` binding that routes/ocr.ts needs via
 * checkRateLimit(); rather than edit the shared lib/env.ts (out of scope
 * for this file's "keep it minimal" goal, and a likely second conflict
 * point with Agent D who needs the same binding for /ai/consultation), we
 * widen the type at the call site instead. Whoever wires up wrangler.toml's
 * `[[kv_namespaces]]` binding should also fold `RateLimitEnv` into `Env`
 * directly at that point.
 */
export default {
  async fetch(request: Request, env: Env & RateLimitEnv): Promise<Response> {
    const url = new URL(request.url);

    if (request.method !== 'POST') {
      return new Response('Not found', { status: 404 });
    }

    switch (url.pathname) {
      case '/ocr/certificate': {
        const { handleOcrCertificate } = await import('./routes/ocr');
        return handleOcrCertificate(request, env);
      }
      case '/ai/consultation': {
        const { handleConsultation } = await import('./routes/consultation');
        return handleConsultation(request, env);
      }
      case '/ai/report': {
        const { handleReport } = await import('./routes/report');
        return handleReport(request, env);
      }
      default:
        return new Response('Not found', { status: 404 });
    }
  },
};
