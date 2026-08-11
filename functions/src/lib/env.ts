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
  /** RevenueCat secret API key, used by lib/revenueCatClient.ts to call the
   * Promotional Entitlements REST API (routes/grantPromotionalEntitlement.ts,
   * the campaign-code redemption backend). Optional because the RevenueCat
   * dashboard/secret key are not provisioned yet as of writing -- when unset,
   * lib/revenueCatClient.ts falls back to a clearly-labeled mock success
   * result instead of calling the real API, mirroring
   * lib/anthropicClient.ts's callClaude() mock fallback. Set with
   * `wrangler secret put REVENUECAT_SECRET_KEY` once the PM has a real key;
   * never commit a real value. */
  REVENUECAT_SECRET_KEY?: string;
  /** Host:port of the Firestore emulator (local dev only). Its presence is
   * what makes lib/firestoreClient.ts talk to the emulator without
   * credentials; unset in a real deployment, where the service-account pair
   * below is required instead. */
  FIRESTORE_EMULATOR_HOST?: string;
  /** Service-account client email, for lib/firestoreClient.ts. The Worker
   * needs Firestore access to authorize campaign-code redemption itself --
   * see routes/grantPromotionalEntitlement.ts for why that cannot live in
   * the client. Set with `wrangler secret put`; never commit a real value. */
  FIREBASE_CLIENT_EMAIL?: string;
  /** The service account's PEM private key, newlines escaped as `
`
   * (wrangler secrets are single-line). Never commit a real value. */
  FIREBASE_PRIVATE_KEY?: string;
}
