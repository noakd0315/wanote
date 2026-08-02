import type { Env } from '../lib/env';
import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { grantPromotionalEntitlement } from '../lib/revenueCatClient';

/**
 * POST /billing/grant-promotional-entitlement -- campaign-code / referral-code
 * redemption backend (Agent E / billing).
 *
 * The Flutter client (lib/features/billing/data/campaign_code_repository.dart)
 * owns all code-validity/redemption-tracking logic directly against
 * Firestore (campaign_codes/{code}, users/{uid}/redeemed_codes/{code}) --
 * this route's only job, once the client has decided a redemption is
 * eligible, is to actually grant the reward via RevenueCat's Promotional
 * Entitlements API, which requires a secret key that must never reach the
 * client. No request body is needed: the uid comes from the verified
 * Firebase ID token, and both the entitlement and the reward duration are
 * fixed (see constants below) -- there is nothing else for the caller to
 * configure.
 */

/** lib/features/billing/domain/product_ids.dart's EntitlementIds.premium.
 * Kept as a plain string here (rather than importing across the Dart/TS
 * boundary) -- update both together if the RevenueCat dashboard's
 * entitlement identifier ever changes. */
const PREMIUM_ENTITLEMENT_ID = 'premium';

/** "1ヶ月無料" (1 month of premium access), per the PM's explicit spec for
 * this feature. */
const REDEMPTION_DURATION = 'monthly';

/** Abuse-protection ceiling: this endpoint is only ever called once per
 * successful code redemption (and redemption is itself capped client-side
 * by Firestore's "already redeemed" marker), so a generous 5/day/uid only
 * bites actual abuse -- e.g. someone hammering the endpoint directly rather
 * than through the normal redemption flow. */
const RATE_LIMIT = { maxCalls: 5, windowSeconds: 60 * 60 * 24 };

type GrantPromotionalEntitlementEnv = Env & RateLimitEnv;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function handleGrantPromotionalEntitlement(
  request: Request,
  env: GrantPromotionalEntitlementEnv,
): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const rateLimit = await checkRateLimit(env, `grant-promotional-entitlement:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many redemption requests. Please try again later.' }, 429);
  }

  try {
    const result = await grantPromotionalEntitlement({
      env,
      appUserId: uid,
      entitlementIdentifier: PREMIUM_ENTITLEMENT_ID,
      duration: REDEMPTION_DURATION,
    });
    return jsonResponse({ granted: result.granted }, 200);
  } catch {
    return jsonResponse(
      { error: 'Failed to grant promotional entitlement. Please try again later.' },
      502,
    );
  }
}
