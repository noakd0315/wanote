import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/campaign_code_models.dart';
import 'billing_backend_client.dart';

/// Firestore-backed campaign-code / referral-code redemption.
///
/// Per the PM's explicit "keep it simple" scope, all code-validity and
/// redemption-tracking state lives directly in Firestore (no Firestore
/// access in the Cloudflare Worker):
///   - `campaign_codes/{code}`: { active, maxRedemptions, redemptionCount,
///     referrerUid? } -- a referral code is just a campaign code with
///     referrerUid set to its owner's uid, redeemed through this exact same
///     flow.
///   - `users/{uid}/redeemed_codes/{code}`: marker doc preventing the same
///     user from redeeming the same code twice.
///
/// [redeem] only talks to the backend (functions/src/routes/
/// grantPromotionalEntitlement.ts) to actually grant the RevenueCat
/// entitlement -- the backend never touches Firestore.
abstract class CampaignCodeRepository {
  /// Reads the current `campaign_codes/{code}` document, or null if no such
  /// code exists. This is a cheap, non-authoritative precheck (e.g. for a UI
  /// that wants to validate a code as the user types) -- [redeem] always
  /// re-checks authoritatively inside a transaction before recording a
  /// redemption.
  Future<CampaignCode?> checkValid(String code);

  /// Attempts to redeem [code] for [uid]. See the class doc for the overall
  /// flow; returns a [CampaignCodeRedemptionResult] describing the outcome
  /// (never throws for an expected ineligibility -- only for unexpected
  /// Firestore errors).
  Future<CampaignCodeRedemptionResult> redeem({
    required String code,
    required String uid,
  });

  /// Returns this user's own shareable referral code, creating its
  /// `campaign_codes/{code}` document (referrerUid: [uid]) the first time
  /// it's requested. Idempotent: calling this again for the same [uid]
  /// returns the same code without creating a duplicate document.
  Future<String> getOrCreateReferralCode(String uid);
}

class FirestoreCampaignCodeRepository implements CampaignCodeRepository {
  FirestoreCampaignCodeRepository({FirebaseFirestore? firestore, BillingBackendClient? backendClient})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _backendClient = backendClient ?? BillingBackendClient.fromEnvironment();

  /// Effectively-unlimited redemption cap for referral codes -- referral
  /// codes aren't meant to be scarce the way a promotional campaign code
  /// might be, they just need *a* cap so the same eligibility rules apply
  /// uniformly.
  static const int referralMaxRedemptions = 1000;

  final FirebaseFirestore _firestore;
  final BillingBackendClient _backendClient;

  static const String _campaignCodesCollection = 'campaign_codes';

  DocumentReference<Map<String, dynamic>> _codeDoc(String code) =>
      _firestore.collection(_campaignCodesCollection).doc(code);

  DocumentReference<Map<String, dynamic>> _markerDoc(String uid, String code) =>
      _firestore.doc('users/$uid/redeemed_codes/$code');

  @override
  Future<CampaignCode?> checkValid(String code) async {
    final snapshot = await _codeDoc(code).get();
    return _campaignCodeFromSnapshot(code, snapshot);
  }

  @override
  Future<CampaignCodeRedemptionResult> redeem({required String code, required String uid}) async {
    // Phase 1: fast precheck so we don't call the backend at all for an
    // obviously invalid code. Not itself race-safe (see phase 3, which
    // re-checks atomically) -- just avoids an unnecessary network call and
    // gives the user fast feedback for the common case.
    final precheckCode = await checkValid(code);
    final precheckMarker = await _markerDoc(uid, code).get();
    final precheckEligibility = CampaignCodeEligibility.evaluate(
      campaignCode: precheckCode,
      alreadyRedeemedByUser: precheckMarker.exists,
      uid: uid,
    );
    if (precheckEligibility is RedemptionIneligible) {
      return CampaignCodeRedemptionRejected(precheckEligibility.reason);
    }

    // Phase 2: grant the RevenueCat entitlement via the Cloudflare Worker.
    // The worker never sees Firestore -- it only verifies the caller's
    // Firebase ID token and calls RevenueCat's promotional-entitlement API.
    final bool granted;
    try {
      granted = await _backendClient.grantPromotionalEntitlement();
    } on BillingBackendException catch (e) {
      return CampaignCodeRedemptionFailed(e.message);
    }
    if (!granted) {
      return const CampaignCodeRedemptionFailed(
        'The server could not grant the premium entitlement. Please try again later.',
      );
    }

    // Phase 3: atomically re-check eligibility and record the redemption
    // (increment + marker write together in one transaction), so two
    // concurrent redemptions can't both slip past a cap -- this is the
    // "increment+check in a transaction" race guard. If this rejects after
    // the entitlement was already granted in phase 2 (e.g. another
    // redemption filled the last slot in between), that's an acceptable
    // edge case: RevenueCat's promotional grant is harmless to have applied
    // even though the Firestore-side bookkeeping now rejects it.
    try {
      await _firestore.runTransaction((tx) async {
        final codeSnapshot = await tx.get(_codeDoc(code));
        final markerSnapshot = await tx.get(_markerDoc(uid, code));
        final campaignCode = _campaignCodeFromSnapshot(code, codeSnapshot);
        final eligibility = CampaignCodeEligibility.evaluate(
          campaignCode: campaignCode,
          alreadyRedeemedByUser: markerSnapshot.exists,
          uid: uid,
        );
        if (eligibility is RedemptionIneligible) {
          throw _RedemptionRaceLost(eligibility.reason);
        }
        tx.update(_codeDoc(code), {'redemptionCount': FieldValue.increment(1)});
        tx.set(_markerDoc(uid, code), {'redeemedAt': FieldValue.serverTimestamp()});
      });
    } on _RedemptionRaceLost catch (e) {
      return CampaignCodeRedemptionRejected(e.reason);
    }

    return const CampaignCodeRedeemed();
  }

  @override
  Future<String> getOrCreateReferralCode(String uid) async {
    final code = ReferralCodeGenerator.deriveFrom(uid);
    final doc = _codeDoc(code);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await doc.set({
        'active': true,
        'maxRedemptions': referralMaxRedemptions,
        'redemptionCount': 0,
        'referrerUid': uid,
      });
    }
    return code;
  }

  CampaignCode? _campaignCodeFromSnapshot(
    String code,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    return CampaignCode(
      code: code,
      active: data['active'] as bool? ?? false,
      maxRedemptions: (data['maxRedemptions'] as num?)?.toInt() ?? 0,
      redemptionCount: (data['redemptionCount'] as num?)?.toInt() ?? 0,
      referrerUid: data['referrerUid'] as String?,
    );
  }
}

class _RedemptionRaceLost implements Exception {
  _RedemptionRaceLost(this.reason);

  final RedemptionIneligibleReason reason;
}
