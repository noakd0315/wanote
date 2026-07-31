/** Cloudflare Workers bindings shared by every route. Secrets are set with
 * `wrangler secret put <NAME>` and must never be committed to this repo. */
export interface Env {
  ANTHROPIC_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
  /** Local-dev-only flag (set via functions/.dev.vars, see
   * functions/.dev.vars.example). When present, lib/verifyFirebaseToken.ts
   * skips signature verification since the Firebase Auth Emulator issues
   * unsigned ID tokens by design -- this mirrors the real Firebase Admin
   * SDK's own documented behavior when this env var is set. Never set in a
   * real deployment's `wrangler secret` config, so production always keeps
   * full signature verification. */
  FIREBASE_AUTH_EMULATOR_HOST?: string;
}
