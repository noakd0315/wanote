import { createRemoteJWKSet, jwtVerify } from 'jose';
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
