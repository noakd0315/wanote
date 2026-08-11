import { createRemoteJWKSet, decodeJwt, jwtVerify } from 'jose';
import type { Env } from './env';

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

let cachedJwks: ReturnType<typeof createRemoteJWKSet> | null = null;

/** Verifies a Firebase Auth ID token sent as `Authorization: Bearer <token>`
 * so every route can trust `uid` without ever seeing the user's password or
 * biometric data — those never leave the device (spec 1.4). Throws on any
 * verification failure; callers should turn that into a 401. */
export async function verifyFirebaseToken(
  authorizationHeader: string | null,
  env: Env,
): Promise<{ uid: string }> {
  if (!authorizationHeader?.startsWith('Bearer ')) {
    throw new Error('Missing bearer token.');
  }
  const token = authorizationHeader.slice('Bearer '.length);

  // Local-dev-only escape hatch. The Firebase Auth Emulator issues *unsigned*
  // ID tokens by design (it never talks to real Google infrastructure), so
  // verifying them against Google's real JWKS below always fails. The real
  // Firebase Admin SDK has the same problem and solves it the same way: when
  // it sees FIREBASE_AUTH_EMULATOR_HOST set, it skips signature verification
  // for emulator-issued tokens. See
  // https://firebase.google.com/docs/emulator-suite/connect_auth#id_tokens.
  //
  // Guarded by the project id as well as the env var. On its own the env var
  // is one misconfiguration away from catastrophe: anything that carried it
  // into a real deployment -- `wrangler dev --remote`, pasting .dev.vars into
  // `wrangler secret put`, promoting a staging config -- would silently
  // disable signature checking for every request, letting anyone forge an
  // `alg: none` token for any uid and impersonate them on every route,
  // including granting themselves premium.
  //
  // Emulator project ids are always `demo-` prefixed (that prefix is what
  // tells the Firebase tooling a project is fake and must never reach real
  // Google infrastructure), so requiring both makes the unsafe combination
  // structurally impossible rather than merely unlikely.
  if (env.FIREBASE_AUTH_EMULATOR_HOST && isEmulatorProject(env)) {
    return verifyEmulatorToken(token, env);
  }

  cachedJwks ??= createRemoteJWKSet(new URL(JWKS_URL));

  const { payload } = await jwtVerify(token, cachedJwks, {
    issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
    audience: env.FIREBASE_PROJECT_ID,
  });

  if (typeof payload.sub !== 'string') {
    throw new Error('Token payload missing sub claim.');
  }
  return { uid: payload.sub };
}

/** Whether FIREBASE_PROJECT_ID names a Firebase emulator project rather than
 * a real one. `demo-` is Firebase's own reserved prefix for projects that
 * exist only in the Local Emulator Suite. */
function isEmulatorProject(env: Env): boolean {
  return env.FIREBASE_PROJECT_ID.startsWith('demo-');
}

/** Decodes (without verifying the signature) a Firebase Auth Emulator ID
 * token. Still sanity-checks the claims routes rely on, so a garbled or
 * foreign token is still rejected — only the signature check is skipped. */
function verifyEmulatorToken(token: string, env: Env): { uid: string } {
  const payload = decodeJwt(token);
  if (payload.iss !== `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`) {
    throw new Error('Unexpected token issuer.');
  }
  if (payload.aud !== env.FIREBASE_PROJECT_ID) {
    throw new Error('Unexpected token audience.');
  }
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new Error('Token payload missing sub claim.');
  }
  return { uid: payload.sub };
}
