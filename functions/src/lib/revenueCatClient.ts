import type { Env } from './env';

const REVENUECAT_API_URL = 'https://api.revenuecat.com/v1';

/** RevenueCat's promotional-entitlement duration enum -- see
 * https://www.revenuecat.com/docs/api-v1#tag/entitlements/operation/grant-a-promotional-entitlement. */
export type PromotionalDuration =
  | 'daily'
  | 'weekly'
  | 'monthly'
  | 'three_month'
  | 'six_month'
  | 'yearly'
  | 'lifetime';

interface GrantPromotionalEntitlementParams {
  env: Env;
  /** RevenueCat's `app_user_id` -- the same uid Firebase Auth issues, per
   * how lib/features/billing/data/billing_repository.dart's logIn(uid)
   * already identifies RevenueCat customers. */
  appUserId: string;
  /** RevenueCat entitlement identifier, e.g. `EntitlementIds.premium`
   * ("premium") from lib/features/billing/domain/product_ids.dart. */
  entitlementIdentifier: string;
  duration: PromotionalDuration;
}

export interface GrantPromotionalEntitlementResult {
  granted: boolean;
  /** True when this result came from the local mock fallback (no
   * REVENUECAT_SECRET_KEY configured) rather than a real RevenueCat call. */
  mock: boolean;
}

/** Deterministic, unmistakably-fake stand-in for a real RevenueCat grant,
 * used by grantPromotionalEntitlement() below when no REVENUECAT_SECRET_KEY
 * is configured. Lets the campaign-code redemption flow be demoed
 * end-to-end at zero cost and without a RevenueCat account -- see
 * functions/.dev.vars.example. */
function buildMockGrantResult(): GrantPromotionalEntitlementResult {
  return { granted: true, mock: true };
}

/**
 * Thin wrapper around RevenueCat's Promotional Entitlements REST API:
 *   POST /subscribers/{app_user_id}/entitlements/{entitlement_identifier}/promotional
 *   Authorization: Bearer <secret_key>
 *   body: { "duration": "monthly" | ... }
 * Used by routes/grantPromotionalEntitlement.ts to grant the reward for a
 * redeemed campaign/referral code. The RevenueCat secret key never leaves
 * this Worker (must never be client-side).
 *
 * Local-dev fallback: if env.REVENUECAT_SECRET_KEY is empty/unset (the
 * RevenueCat dashboard/secret key are not provisioned yet as of writing),
 * this returns a clearly-labeled mock success result instead of calling the
 * real API or throwing, mirroring lib/anthropicClient.ts's callClaude()
 * mock fallback so the campaign-code flow stays click-through-able for free
 * before RevenueCat is configured. Signature/return shape is unchanged
 * either way.
 */
export async function grantPromotionalEntitlement({
  env,
  appUserId,
  entitlementIdentifier,
  duration,
}: GrantPromotionalEntitlementParams): Promise<GrantPromotionalEntitlementResult> {
  if (!env.REVENUECAT_SECRET_KEY || env.REVENUECAT_SECRET_KEY.trim().length === 0) {
    console.warn(
      '[revenueCatClient] REVENUECAT_SECRET_KEY is not set — returning a mock granted result ' +
        'instead of calling the real RevenueCat API. See functions/.dev.vars.example to configure a real key.',
    );
    return buildMockGrantResult();
  }

  const url =
    `${REVENUECAT_API_URL}/subscribers/${encodeURIComponent(appUserId)}` +
    `/entitlements/${encodeURIComponent(entitlementIdentifier)}/promotional`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${env.REVENUECAT_SECRET_KEY}`,
    },
    body: JSON.stringify({ duration }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`RevenueCat API error ${response.status}: ${body}`);
  }

  return { granted: true, mock: false };
}

/**
 * Whether [appUserId] currently has [entitlementIdentifier] from a real
 * purchase, used to decide between granting a reward now and deferring it.
 *
 * Granting a promotional entitlement to someone who already has the same
 * entitlement is wasted: it overlaps the paid one and expires underneath it,
 * so an annual subscriber would receive nothing. See routes/grantOrDefer.ts.
 *
 * Local-dev fallback: with no secret key configured this reports "not
 * subscribed", which keeps the redemption flow granting immediately so it
 * stays demoable end-to-end -- same spirit as the mock grant above.
 */
export async function hasActiveEntitlement({
  env,
  appUserId,
  entitlementIdentifier,
}: {
  env: Env;
  appUserId: string;
  entitlementIdentifier: string;
}): Promise<boolean> {
  if (!env.REVENUECAT_SECRET_KEY || env.REVENUECAT_SECRET_KEY.trim().length === 0) {
    return false;
  }

  const url = `${REVENUECAT_API_URL}/subscribers/${encodeURIComponent(appUserId)}`;
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${env.REVENUECAT_SECRET_KEY}` },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`RevenueCat API error ${response.status}: ${body}`);
  }

  const payload = (await response.json()) as {
    subscriber?: {
      entitlements?: Record<string, { expires_date?: string | null }>;
    };
  };
  const entitlement = payload.subscriber?.entitlements?.[entitlementIdentifier];
  if (!entitlement) return false;
  // A null expiry is a lifetime grant, which is active by definition.
  if (!entitlement.expires_date) return true;
  return new Date(entitlement.expires_date).getTime() > Date.now();
}
