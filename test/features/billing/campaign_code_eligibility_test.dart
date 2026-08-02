import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/billing/domain/campaign_code_models.dart';

CampaignCode _code({
  bool active = true,
  int maxRedemptions = 100,
  int redemptionCount = 0,
  String? referrerUid,
}) {
  return CampaignCode(
    code: 'SUMMER2026',
    active: active,
    maxRedemptions: maxRedemptions,
    redemptionCount: redemptionCount,
    referrerUid: referrerUid,
  );
}

void main() {
  group('CampaignCodeEligibility.evaluate', () {
    test('unknown code (no campaign_codes/{code} document): ineligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: null,
        alreadyRedeemedByUser: false,
      );

      expect(result, isA<RedemptionIneligible>());
      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.unknownCode,
      );
    });

    test('inactive code: ineligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(active: false),
        alreadyRedeemedByUser: false,
      );

      expect(result, isA<RedemptionIneligible>());
      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.inactive,
      );
    });

    test('active code, already redeemed by this user: ineligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(),
        alreadyRedeemedByUser: true,
      );

      expect(result, isA<RedemptionIneligible>());
      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.alreadyRedeemedByUser,
      );
    });

    test('active code, under the redemption cap, not yet redeemed by this user: eligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(maxRedemptions: 100, redemptionCount: 50),
        alreadyRedeemedByUser: false,
      );

      expect(result, isA<RedemptionEligible>());
    });

    test('active code exactly at the redemption cap: ineligible (cap reached)', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(maxRedemptions: 100, redemptionCount: 100),
        alreadyRedeemedByUser: false,
      );

      expect(result, isA<RedemptionIneligible>());
      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.redemptionCapReached,
      );
    });

    test('active code over the redemption cap (redemptionCount > maxRedemptions): ineligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(maxRedemptions: 100, redemptionCount: 101),
        alreadyRedeemedByUser: false,
      );

      expect(result, isA<RedemptionIneligible>());
      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.redemptionCapReached,
      );
    });

    test('active code, one redemption remaining (under cap by exactly 1): eligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(maxRedemptions: 100, redemptionCount: 99),
        alreadyRedeemedByUser: false,
      );

      expect(result, isA<RedemptionEligible>());
    });

    test('referral code redeemed by its own referrer: ineligible (self-referral)', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(referrerUid: 'user-1'),
        alreadyRedeemedByUser: false,
        uid: 'user-1',
      );

      expect(result, isA<RedemptionIneligible>());
      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.selfReferral,
      );
    });

    test('referral code redeemed by someone other than its referrer: eligible', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(referrerUid: 'user-1'),
        alreadyRedeemedByUser: false,
        uid: 'user-2',
      );

      expect(result, isA<RedemptionEligible>());
    });

    test('inactive takes priority over redemption cap when both apply', () {
      final result = CampaignCodeEligibility.evaluate(
        campaignCode: _code(active: false, maxRedemptions: 1, redemptionCount: 1),
        alreadyRedeemedByUser: false,
      );

      expect(
        (result as RedemptionIneligible).reason,
        RedemptionIneligibleReason.inactive,
      );
    });
  });

  group('CampaignCode.hasRedemptionsRemaining', () {
    test('true when under the cap', () {
      expect(_code(maxRedemptions: 10, redemptionCount: 9).hasRedemptionsRemaining, isTrue);
    });

    test('false when exactly at the cap', () {
      expect(_code(maxRedemptions: 10, redemptionCount: 10).hasRedemptionsRemaining, isFalse);
    });

    test('false when over the cap', () {
      expect(_code(maxRedemptions: 10, redemptionCount: 11).hasRedemptionsRemaining, isFalse);
    });
  });

  group('ReferralCodeGenerator.deriveFrom', () {
    test('is deterministic for the same uid', () {
      final a = ReferralCodeGenerator.deriveFrom('abcdef1234567890');
      final b = ReferralCodeGenerator.deriveFrom('abcdef1234567890');
      expect(a, b);
    });

    test('differs for different uids', () {
      final a = ReferralCodeGenerator.deriveFrom('userAAAAAAAA');
      final b = ReferralCodeGenerator.deriveFrom('userBBBBBBBB');
      expect(a, isNot(b));
    });

    test('handles a uid shorter than the short-id length without throwing', () {
      expect(() => ReferralCodeGenerator.deriveFrom('abc'), returnsNormally);
    });
  });
}
