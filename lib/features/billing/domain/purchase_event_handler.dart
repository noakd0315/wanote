import '../../../shared/services/ai_usage_repository.dart';
import 'billing_models.dart';
import 'product_ids.dart';

/// Decides what to do with an [AiUsageRepository] in response to a
/// [PurchaseEvent] coming out of [BillingRepository].
///
/// Deliberately kept free of any RevenueCat SDK type in its public API (see
/// [PurchaseEvent]/[EntitlementStateChanged]/[ConsumableProductPurchased] in
/// billing_models.dart) so this class is testable with plain Dart values and
/// a fake [AiUsageRepository] — no network, no purchases_flutter, no
/// widgets.
///
/// Mapping per spec 8.3 ("purchase detection must credit ticket balance /
/// flip the unlimited flag"):
///   - ai_tickets_5 purchased  -> creditTickets(uid, 5)
///   - ai_tickets_15 purchased -> creditTickets(uid, 15)
///   - premium entitlement becomes active   -> setUnlimitedSubscription(uid, true)
///   - premium entitlement becomes inactive -> setUnlimitedSubscription(uid, false)
/// Anything else (unrecognized product id, or an entitlement id other than
/// [EntitlementIds.premium]) is a no-op — it must never throw, since an
/// unrecognized event is expected to occur (e.g. a future SKU added on the
/// RevenueCat dashboard before this class is updated to handle it).
class PurchaseEventHandler {
  PurchaseEventHandler({required AiUsageRepository aiUsageRepository})
    // ignore: prefer_initializing_formals
    : _aiUsageRepository = aiUsageRepository;

  final AiUsageRepository _aiUsageRepository;

  Future<void> handle({required String uid, required PurchaseEvent event}) {
    return switch (event) {
      ConsumableProductPurchased(:final productId, :final transactionId) =>
        _handleConsumable(uid, productId, transactionId),
      EntitlementStateChanged(:final entitlementId, :final isActive) =>
        _handleEntitlement(uid, entitlementId, isActive),
    };
  }

  Future<void> _handleConsumable(
    String uid,
    String productId,
    String transactionId,
  ) {
    switch (productId) {
      case ProductIds.aiTickets5:
        return _aiUsageRepository.creditTickets(
          uid,
          5,
          transactionId: transactionId,
        );
      case ProductIds.aiTickets15:
        return _aiUsageRepository.creditTickets(
          uid,
          15,
          transactionId: transactionId,
        );
      default:
        // Unknown/unrelated consumable product id: no-op, not an error.
        return Future<void>.value();
    }
  }

  Future<void> _handleEntitlement(
    String uid,
    String entitlementId,
    bool isActive,
  ) {
    if (entitlementId != EntitlementIds.premium) {
      // An entitlement id we don't have any policy for: no-op.
      return Future<void>.value();
    }
    return _aiUsageRepository.setUnlimitedSubscription(uid, isActive);
  }
}
