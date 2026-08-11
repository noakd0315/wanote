import { describe, expect, it } from 'vitest';

import { evaluateEligibility, type CampaignCode } from '../src/lib/campaignCodeEligibility';

/**
 * These rules decide whether a user gets a free month of premium, so they are
 * now enforced on the server -- the Dart copy in campaign_code_models.dart is
 * only there to give fast feedback. Before this moved, the endpoint granted
 * premium to anyone who asked, so these were effectively unenforced.
 *
 * The reason strings are part of the contract: the Flutter UI maps them onto
 * RedemptionIneligibleReason to pick a localized message, so renaming one
 * here silently degrades the app to a generic error.
 */

const code = (overrides: Partial<CampaignCode> = {}): CampaignCode => ({
  active: true,
  maxRedemptions: 10,
  redemptionCount: 0,
  referrerUid: null,
  ...overrides,
});

describe('evaluateEligibility', () => {
  it('allows a normal redemption', () => {
    expect(
      evaluateEligibility({ code: code(), alreadyRedeemedByUser: false, uid: 'u1' }),
    ).toEqual({ eligible: true });
  });

  it('rejects a code that does not exist', () => {
    expect(
      evaluateEligibility({ code: null, alreadyRedeemedByUser: false, uid: 'u1' }),
    ).toEqual({ eligible: false, reason: 'unknownCode' });
  });

  it('rejects a deactivated code', () => {
    expect(
      evaluateEligibility({
        code: code({ active: false }),
        alreadyRedeemedByUser: false,
        uid: 'u1',
      }),
    ).toEqual({ eligible: false, reason: 'inactive' });
  });

  it('rejects redeeming your own referral code', () => {
    expect(
      evaluateEligibility({
        code: code({ referrerUid: 'u1' }),
        alreadyRedeemedByUser: false,
        uid: 'u1',
      }),
    ).toEqual({ eligible: false, reason: 'selfReferral' });
  });

  it("does not mistake someone else's referral code for self-referral", () => {
    expect(
      evaluateEligibility({
        code: code({ referrerUid: 'u2' }),
        alreadyRedeemedByUser: false,
        uid: 'u1',
      }),
    ).toEqual({ eligible: true });
  });

  it('rejects a second redemption by the same user', () => {
    expect(
      evaluateEligibility({ code: code(), alreadyRedeemedByUser: true, uid: 'u1' }),
    ).toEqual({ eligible: false, reason: 'alreadyRedeemedByUser' });
  });

  it('rejects once the cap is reached', () => {
    expect(
      evaluateEligibility({
        code: code({ maxRedemptions: 3, redemptionCount: 3 }),
        alreadyRedeemedByUser: false,
        uid: 'u1',
      }),
    ).toEqual({ eligible: false, reason: 'redemptionCapReached' });
  });

  it('rejects a count that somehow exceeded the cap', () => {
    // Defensive: a stored count above the cap must still block, not wrap
    // around into "capacity remaining".
    expect(
      evaluateEligibility({
        code: code({ maxRedemptions: 3, redemptionCount: 9 }),
        alreadyRedeemedByUser: false,
        uid: 'u1',
      }),
    ).toEqual({ eligible: false, reason: 'redemptionCapReached' });
  });

  it('reports self-referral ahead of an already-redeemed marker', () => {
    // Both apply; the more specific reason is the more useful message.
    expect(
      evaluateEligibility({
        code: code({ referrerUid: 'u1' }),
        alreadyRedeemedByUser: true,
        uid: 'u1',
      }),
    ).toEqual({ eligible: false, reason: 'selfReferral' });
  });
});
