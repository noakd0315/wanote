/**
 * Whether a user may redeem a campaign code, decided on the server.
 *
 * A port of lib/features/billing/domain/campaign_code_models.dart's
 * CampaignCodeEligibility. The Dart copy still runs, but only to give the
 * user fast feedback -- it is advice, not authorization. This copy is the one
 * that decides, because it is the only one an attacker cannot skip: the old
 * flow let the client conclude "eligible" and then simply ask the Worker for
 * premium, with the Worker checking nothing.
 *
 * The two must agree on the *reasons*, since the Flutter UI maps them to
 * localized messages -- keep RedemptionIneligibleReason in step with the enum
 * in campaign_code_models.dart.
 */

export type IneligibleReason =
  | 'unknownCode'
  | 'inactive'
  | 'selfReferral'
  | 'alreadyRedeemedByUser'
  | 'redemptionCapReached';

export interface CampaignCode {
  active: boolean;
  maxRedemptions: number;
  redemptionCount: number;
  /** Set on referral codes: the user who owns the code. */
  referrerUid: string | null;
}

export type Eligibility = { eligible: true } | { eligible: false; reason: IneligibleReason };

export function evaluateEligibility({
  code,
  alreadyRedeemedByUser,
  uid,
}: {
  code: CampaignCode | null;
  alreadyRedeemedByUser: boolean;
  uid: string;
}): Eligibility {
  if (code === null) {
    return { eligible: false, reason: 'unknownCode' };
  }
  if (!code.active) {
    return { eligible: false, reason: 'inactive' };
  }
  // Checked before the already-redeemed marker so redeeming your own code
  // reports the specific reason rather than a generic one.
  if (code.referrerUid !== null && code.referrerUid === uid) {
    return { eligible: false, reason: 'selfReferral' };
  }
  if (alreadyRedeemedByUser) {
    return { eligible: false, reason: 'alreadyRedeemedByUser' };
  }
  if (code.redemptionCount >= code.maxRedemptions) {
    return { eligible: false, reason: 'redemptionCapReached' };
  }
  return { eligible: true };
}
