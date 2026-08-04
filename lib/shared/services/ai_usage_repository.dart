import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// Snapshot of one account's AI-consultation entitlement, per spec 6.4:
/// free plan = 3/month, consumable ticket packs, or unlimited subscription.
class AiUsageStatus {
  const AiUsageStatus({
    required this.freeConsultationsRemainingThisMonth,
    required this.ticketsRemaining,
    required this.hasUnlimitedSubscription,
  });

  final int freeConsultationsRemainingThisMonth;
  final int ticketsRemaining;
  final bool hasUnlimitedSubscription;

  bool get canStartConsultation =>
      hasUnlimitedSubscription ||
      freeConsultationsRemainingThisMonth > 0 ||
      ticketsRemaining > 0;
}

/// Shared contract between features/ai (which gates and decrements usage on
/// every consultation) and features/billing (which credits tickets / flips
/// the unlimited flag when RevenueCat reports a purchase). Living in
/// shared/ — rather than inside features/ai/ — is what lets billing/ depend
/// on it without importing another feature's internals, per
/// wanote/.claude/CLAUDE.md's directory-ownership rule.
abstract class AiUsageRepository {
  Future<AiUsageStatus> getStatus(String uid);

  /// Called by features/ai right before invoking the consultation backend.
  /// Decrements free quota first, then tickets. Throws a [StateError] if
  /// [AiUsageStatus.canStartConsultation] was false.
  Future<void> recordConsultationUsed(String uid);

  /// Called by features/billing after a consumable ticket-pack purchase.
  Future<void> creditTickets(String uid, int count);

  /// Called by features/billing when the premium subscription's active
  /// state changes (RevenueCat entitlement callback).
  Future<void> setUnlimitedSubscription(String uid, bool active);
}

class FirestoreAiUsageRepository implements AiUsageRepository {
  FirestoreAiUsageRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int freeMonthlyQuota = 3;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.doc('${FirestorePaths.usageCounters(uid)}/current');

  String _currentPeriodKey() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Future<AiUsageStatus> getStatus(String uid) async {
    final snapshot = await _doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return const AiUsageStatus(
        freeConsultationsRemainingThisMonth:
            FirestoreAiUsageRepository.freeMonthlyQuota,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: false,
      );
    }
    final storedPeriod = data['period'] as String?;
    final usedThisMonth = storedPeriod == _currentPeriodKey()
        ? (data['free_used'] as num?)?.toInt() ?? 0
        : 0;
    return AiUsageStatus(
      freeConsultationsRemainingThisMonth: (freeMonthlyQuota - usedThisMonth)
          .clamp(0, freeMonthlyQuota),
      ticketsRemaining: (data['tickets_remaining'] as num?)?.toInt() ?? 0,
      hasUnlimitedSubscription: data['unlimited'] as bool? ?? false,
    );
  }

  @override
  Future<void> recordConsultationUsed(String uid) async {
    final status = await getStatus(uid);
    if (!status.canStartConsultation) {
      throw StateError('AI usage limit reached for $uid.');
    }
    if (status.hasUnlimitedSubscription) return;

    if (status.freeConsultationsRemainingThisMonth > 0) {
      final usedThisMonth =
          freeMonthlyQuota - status.freeConsultationsRemainingThisMonth + 1;
      await _doc(uid).set({
        'period': _currentPeriodKey(),
        'free_used': usedThisMonth,
      }, SetOptions(merge: true));
    } else {
      await _doc(uid).set({
        'tickets_remaining': status.ticketsRemaining - 1,
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> creditTickets(String uid, int count) async {
    await _doc(uid).set({
      'tickets_remaining': FieldValue.increment(count),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setUnlimitedSubscription(String uid, bool active) async {
    await _doc(uid).set({'unlimited': active}, SetOptions(merge: true));
  }
}
