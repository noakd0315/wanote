/** Cloudflare Workers bindings shared by every route. Secrets are set with
 * `wrangler secret put <NAME>` and must never be committed to this repo. */
export interface Env {
  ANTHROPIC_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
}
