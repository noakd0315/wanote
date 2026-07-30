import type { Env } from './lib/env';

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
 */
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method !== 'POST') {
      return new Response('Not found', { status: 404 });
    }

    switch (url.pathname) {
      // case '/ocr/certificate': {
      //   const { handleOcrCertificate } = await import('./routes/ocr');
      //   return handleOcrCertificate(request, env);
      // }
      // case '/ai/consultation': {
      //   const { handleConsultation } = await import('./routes/consultation');
      //   return handleConsultation(request, env);
      // }
      // case '/ai/report': {
      //   const { handleReport } = await import('./routes/report');
      //   return handleReport(request, env);
      // }
      default:
        return new Response('Not found', { status: 404 });
    }
  },
};
