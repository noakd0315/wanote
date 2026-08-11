import '../domain/campaign_code_models.dart';
import 'billing_backend_client.dart';

/// Campaign-code / referral-code redemption, decided by the backend.
///
/// Redemption state still lives in Firestore --
///   - `campaign_codes/{code}`: { active, maxRedemptions, redemptionCount,
///     referrerUid? }; a referral code is just a campaign code with
///     referrerUid set to its owner's uid, redeemed through the same flow.
///   - `users/{uid}/redeemed_codes/{code}`: marker preventing the same user
///     from redeeming the same code twice.
///
/// -- but this class no longer reads or writes any of it. Both collections
/// are now closed to clients in firestore.rules, and every decision happens
/// in functions/src/routes/grantPromotionalEntitlement.ts inside a Firestore
/// transaction.
///
/// It used to work the other way round: this repository ran the transaction
/// and the Worker granted the entitlement on request, checking nothing. That
/// meant the eligibility rules were advisory -- any account could call the
/// grant endpoint directly and hand itself premium, repeatedly, without a
/// code. Rules alone could not fix it, because a client that is allowed to
/// record its own redemption is also allowed to skip recording one.
abstract class CampaignCodeRepository {
  /// Attempts to redeem [code]. Returns a [CampaignCodeRedemptionResult]
  /// describing the outcome; never throws for an expected ineligibility.
  ///
  /// [uid] is no longer used to decide anything -- the backend takes the uid
  /// from the verified ID token, which is the only copy an attacker cannot
  /// choose -- but is kept in the signature so callers stay unchanged.
  Future<CampaignCodeRedemptionResult> redeem({
    required String code,
    required String uid,
  });

  /// Returns this user's own shareable referral code, creating it on the
  /// backend the first time. Idempotent.
  Future<String> getOrCreateReferralCode(String uid);
}

class FirestoreCampaignCodeRepository implements CampaignCodeRepository {
  FirestoreCampaignCodeRepository({BillingBackendClient? backendClient})
    : _backendClient = backendClient ?? BillingBackendClient.fromEnvironment();

  final BillingBackendClient _backendClient;

  @override
  Future<CampaignCodeRedemptionResult> redeem({
    required String code,
    required String uid,
  }) async {
    final BackendRedemptionResult result;
    try {
      result = await _backendClient.grantPromotionalEntitlement(code);
    } on BillingBackendException catch (e) {
      return CampaignCodeRedemptionFailed(e.message);
    }

    if (result.granted) return const CampaignCodeRedeemed();

    final reason = _reasonFromName(result.reason);
    if (reason == null) {
      return const CampaignCodeRedemptionFailed(
        'The server could not grant the premium entitlement. Please try again later.',
      );
    }
    return CampaignCodeRedemptionRejected(reason);
  }

  @override
  Future<String> getOrCreateReferralCode(String uid) =>
      _backendClient.fetchReferralCode();

  /// Maps the backend's machine-readable reason back onto the Dart enum the
  /// UI localizes. An unrecognized value is treated as a failure rather than
  /// guessed at, so a backend that grows a new reason shows a generic error
  /// instead of the wrong explanation.
  RedemptionIneligibleReason? _reasonFromName(String? name) {
    for (final reason in RedemptionIneligibleReason.values) {
      if (reason.name == name) return reason;
    }
    return null;
  }
}
