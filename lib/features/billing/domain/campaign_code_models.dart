// Plain-Dart models for the campaign-code / referral-code redemption
// feature, kept free of any Firestore/http types so [CampaignCodeEligibility]
// is trivially unit-testable -- same spirit as [AdPolicy] and
// [PurchaseEventHandler] elsewhere in this feature.

/// Snapshot of a `campaign_codes/{code}` Firestore document (see
/// `data/campaign_code_repository.dart`), read into a plain Dart value.
///
/// A referral code is just a campaign code with [referrerUid] set to the
/// referring user's uid and a generous [maxRedemptions] -- it is redeemed
/// through the exact same flow, there is no parallel referral system.
class CampaignCode {
  const CampaignCode({
    required this.code,
    required this.active,
    required this.maxRedemptions,
    required this.redemptionCount,
    this.referrerUid,
  });

  final String code;
  final bool active;
  final int maxRedemptions;
  final int redemptionCount;

  /// Set only for referral codes: the uid of the user who owns/shares this
  /// code. Null for ordinary (non-referral) campaign codes.
  final String? referrerUid;

  bool get hasRedemptionsRemaining => redemptionCount < maxRedemptions;

  @override
  String toString() =>
      'CampaignCode(code: $code, active: $active, redemptionCount: $redemptionCount/$maxRedemptions, referrerUid: $referrerUid)';
}

/// Why [CampaignCodeEligibility.evaluate] rejected a redemption attempt.
enum RedemptionIneligibleReason {
  /// No `campaign_codes/{code}` document exists for the entered code.
  unknownCode,

  /// The code exists but has been deactivated (`active: false`).
  inactive,

  /// `redemptionCount >= maxRedemptions` -- the code has no slots left.
  redemptionCapReached,

  /// This uid already has a `users/{uid}/redeemed_codes/{code}` marker.
  alreadyRedeemedByUser,

  /// The code is a referral code and the redeeming uid is the same as its
  /// [CampaignCode.referrerUid] -- a user can't refer themselves.
  selfReferral,
}

/// Result of [CampaignCodeEligibility.evaluate]: either eligible, or
/// ineligible with a specific reason the UI can turn into a message.
sealed class RedemptionEligibility {
  const RedemptionEligibility();
}

class RedemptionEligible extends RedemptionEligibility {
  const RedemptionEligible();
}

class RedemptionIneligible extends RedemptionEligibility {
  const RedemptionIneligible(this.reason);

  final RedemptionIneligibleReason reason;
}

/// Pure decision of whether [uid] may redeem [campaignCode] right now.
/// Factored out of `data/campaign_code_repository.dart`'s Firestore
/// transaction so the eligibility rules (active/inactive, redemption cap,
/// already-redeemed-by-this-user, unknown code, self-referral) are
/// unit-testable without a real Firestore -- see
/// test/features/billing/campaign_code_eligibility_test.dart.
class CampaignCodeEligibility {
  const CampaignCodeEligibility._();

  /// [campaignCode] is null when no `campaign_codes/{code}` document exists
  /// for the entered code (unknown code). [alreadyRedeemedByUser] reflects
  /// whether a `users/{uid}/redeemed_codes/{code}` marker already exists.
  /// [uid] is only used to detect self-referral; pass null (or omit) when
  /// checking a code before a user is known.
  static RedemptionEligibility evaluate({
    required CampaignCode? campaignCode,
    required bool alreadyRedeemedByUser,
    String? uid,
  }) {
    if (campaignCode == null) {
      return const RedemptionIneligible(RedemptionIneligibleReason.unknownCode);
    }
    if (!campaignCode.active) {
      return const RedemptionIneligible(RedemptionIneligibleReason.inactive);
    }
    if (uid != null && campaignCode.referrerUid == uid) {
      return const RedemptionIneligible(RedemptionIneligibleReason.selfReferral);
    }
    if (alreadyRedeemedByUser) {
      return const RedemptionIneligible(RedemptionIneligibleReason.alreadyRedeemedByUser);
    }
    if (!campaignCode.hasRedemptionsRemaining) {
      return const RedemptionIneligible(RedemptionIneligibleReason.redemptionCapReached);
    }
    return const RedemptionEligible();
  }
}

/// Outcome of `CampaignCodeRepository.redeem()`.
sealed class CampaignCodeRedemptionResult {
  const CampaignCodeRedemptionResult();
}

class CampaignCodeRedeemed extends CampaignCodeRedemptionResult {
  const CampaignCodeRedeemed();
}

class CampaignCodeRedemptionRejected extends CampaignCodeRedemptionResult {
  const CampaignCodeRedemptionRejected(this.reason);

  final RedemptionIneligibleReason reason;
}

/// The Firestore-side checks passed but the backend call to grant the
/// RevenueCat entitlement failed (network error, backend error response).
class CampaignCodeRedemptionFailed extends CampaignCodeRedemptionResult {
  const CampaignCodeRedemptionFailed(this.message);

  final String message;
}

/// Pure derivation of a short, human-typeable referral code from a uid.
/// Deterministic so calling it twice for the same uid always yields the
/// same code (no need to persist a separately-generated random code).
class ReferralCodeGenerator {
  const ReferralCodeGenerator._();

  static const int _shortIdLength = 8;

  static String deriveFrom(String uid) {
    final shortId = uid.length <= _shortIdLength ? uid : uid.substring(0, _shortIdLength);
    return 'REF-${shortId.toUpperCase()}';
  }
}
