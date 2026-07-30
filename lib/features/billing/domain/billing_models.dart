// Plain-Dart models the billing feature uses at its public boundaries
// (PurchaseEventHandler, AdPolicy) so that RevenueCat SDK types
// (CustomerInfo, EntitlementInfo, ...) never have to leak into code that
// should be trivially unit-testable without the SDK.

/// Whether the account's "premium" entitlement (shared by premium_monthly
/// and premium_yearly, spec 8.2) is currently active.
///
/// [unknown] models the window before RevenueCat has delivered its first
/// CustomerInfo snapshot (app just launched, purchase SDK still
/// initializing). See [AdPolicy] for how that transitional state is
/// resolved for ad display.
enum EntitlementState { active, inactive, unknown }

class PremiumStatus {
  const PremiumStatus(this.state);

  final EntitlementState state;

  bool get isActive => state == EntitlementState.active;

  static const PremiumStatus unknown = PremiumStatus(EntitlementState.unknown);
  static const PremiumStatus active = PremiumStatus(EntitlementState.active);
  static const PremiumStatus inactive = PremiumStatus(
    EntitlementState.inactive,
  );

  @override
  bool operator ==(Object other) =>
      other is PremiumStatus && other.state == state;

  @override
  int get hashCode => state.hashCode;

  @override
  String toString() => 'PremiumStatus(${state.name})';
}

/// A purchase/entitlement-update notification coming out of
/// [BillingRepository], already mapped away from RevenueCat's own types.
///
/// Modeled as a sealed class (rather than importing purchases_flutter's
/// CustomerInfo/EntitlementInfo) so [PurchaseEventHandler] can be tested with
/// plain Dart values and a fake AiUsageRepository, no RevenueCat SDK or
/// network access required.
sealed class PurchaseEvent {
  const PurchaseEvent();
}

/// A consumable (non-subscription) product finished purchasing. RevenueCat
/// doesn't model consumables as entitlements, so this is raised directly
/// from the purchase() call site in the repository rather than from a
/// CustomerInfo diff.
class ConsumableProductPurchased extends PurchaseEvent {
  const ConsumableProductPurchased(this.productId);

  final String productId;

  @override
  String toString() => 'ConsumableProductPurchased($productId)';
}

/// The named entitlement's active flag flipped (new purchase, renewal,
/// expiration, cancellation, billing-issue resolution, refund, ...). Only
/// the resulting boolean matters to this feature — we intentionally don't
/// carry *why* it changed.
class EntitlementStateChanged extends PurchaseEvent {
  const EntitlementStateChanged({
    required this.entitlementId,
    required this.isActive,
  });

  final String entitlementId;
  final bool isActive;

  @override
  String toString() =>
      'EntitlementStateChanged($entitlementId, isActive: $isActive)';
}
