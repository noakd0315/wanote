import { commit, type FirestoreEnv } from './firestoreClient';
import { grantPromotionalEntitlement, hasActiveEntitlement } from './revenueCatClient';

/**
 * Gives a user their month of premium -- now if it would actually be worth
 * something, or later if it would not.
 *
 * A promotional entitlement runs from the moment it is granted, and it does
 * not touch the App Store / Google Play subscription underneath it. Grant one
 * to someone with eight months of an annual plan left and it simply overlaps
 * and expires unnoticed: they receive nothing. That matters most for the
 * referral reward, because the people who refer others are the people most
 * likely to be subscribers (PM decision: 保留付与方式).
 *
 * So when the entitlement is already active, the reward is recorded instead
 * and applied the first time the user is not covered -- see
 * routes/applyPendingGrants.ts. Nothing expires unused, and nobody is
 * rewarded for cancelling: from the user's side their premium simply
 * continues for a month past the end of what they paid for.
 */

export const PREMIUM_ENTITLEMENT_ID = 'premium';
export const REDEMPTION_DURATION = 'monthly';

/** Pending grants are not worth honouring forever. PM decision: 1 year. */
export const PENDING_GRANT_TTL_MS = 365 * 24 * 60 * 60 * 1000;

export type GrantReason = 'redemption' | 'referral';

export type GrantOutcome = 'granted' | 'deferred';

/**
 * Grants immediately, or records a pending grant. Returns which happened so
 * the caller can tell the user.
 *
 * [idempotencyKey] becomes the pending document's id, so retrying the same
 * logical reward cannot pile up duplicates.
 */
export async function grantOrDefer({
  env,
  uid,
  reason,
  idempotencyKey,
}: {
  env: FirestoreEnv;
  uid: string;
  reason: GrantReason;
  idempotencyKey: string;
}): Promise<GrantOutcome> {
  const alreadyPremium = await hasActiveEntitlement({
    env,
    appUserId: uid,
    entitlementIdentifier: PREMIUM_ENTITLEMENT_ID,
  });

  if (!alreadyPremium) {
    await grantPromotionalEntitlement({
      env,
      appUserId: uid,
      entitlementIdentifier: PREMIUM_ENTITLEMENT_ID,
      duration: REDEMPTION_DURATION,
    });
    return 'granted';
  }

  const now = Date.now();
  await commit(env, null, [
    {
      path: `users/${uid}/pending_grants/${idempotencyKey}`,
      fields: {
        reason: { stringValue: reason },
        months: { integerValue: '1' },
        createdAt: { timestampValue: new Date(now).toISOString() },
        expiresAt: {
          timestampValue: new Date(now + PENDING_GRANT_TTL_MS).toISOString(),
        },
      },
      // Never overwrite an existing pending grant: a retry of the same
      // reward must not reset its expiry or resurrect an applied one.
      mustExist: false,
    },
  ]);
  return 'deferred';
}
