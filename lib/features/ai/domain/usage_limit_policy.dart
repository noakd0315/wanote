import '../../../shared/services/ai_usage_repository.dart';

/// What the consultation screen should do given the caller's current
/// [AiUsageStatus] (spec 6.4's plan table: free monthly quota, consumable
/// ticket packs, unlimited subscription).
enum UsageLimitDecision {
  /// Proceed with calling the consultation backend.
  allow,

  /// Every quota is exhausted: show the ticket-purchase / subscription
  /// upgrade prompt instead of consulting. This is the hook point for Agent
  /// E's billing screens (RevenueCat paywall / ticket-pack purchase), which
  /// features/ai deliberately does not import directly.
  requireUpgrade,
}

/// Thin, pure decision layer around [AiUsageStatus.canStartConsultation].
///
/// This intentionally does not duplicate the free/ticket/unlimited
/// arithmetic that already lives on [AiUsageStatus] in shared/ — that would
/// risk the two definitions drifting apart. It exists so:
///   1. features/ai's screens have a single, named, testable seam to call
///      instead of inlining `status.canStartConsultation ? ... : ...`
///      throughout the UI layer, and
///   2. the "usage counting" test requirement can be satisfied against a
///      fake [AiUsageRepository] without touching Firestore, per the
///      exercise in test/features/ai/domain/usage_limit_policy_test.dart.
class UsageLimitPolicy {
  const UsageLimitPolicy();

  UsageLimitDecision decide(AiUsageStatus status) {
    return status.canStartConsultation
        ? UsageLimitDecision.allow
        : UsageLimitDecision.requireUpgrade;
  }

  /// Convenience wrapper that fetches the latest status from [repository]
  /// first. Screens call this right before invoking the consultation
  /// backend (requirement #2 in the task brief).
  Future<UsageLimitDecision> decideForUser(
    AiUsageRepository repository,
    String uid,
  ) async {
    final status = await repository.getStatus(uid);
    return decide(status);
  }
}
