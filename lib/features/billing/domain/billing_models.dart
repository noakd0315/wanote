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
  const PremiumStatus(this.state, {this.expiresAt});

  final EntitlementState state;

  /// When the entitlement runs out, if RevenueCat gave a date.
  ///
  /// Carried because a free month delivered by a campaign or referral code
  /// otherwise ends without warning -- the owner is told they have a month
  /// and then has no way to find out when it started (PM, 2026-08-21).
  ///
  /// Null for a lifetime grant, and null whenever the state is not active.
  final DateTime? expiresAt;

  bool get isActive => state == EntitlementState.active;

  static const PremiumStatus unknown = PremiumStatus(EntitlementState.unknown);
  static const PremiumStatus active = PremiumStatus(EntitlementState.active);
  static const PremiumStatus inactive = PremiumStatus(
    EntitlementState.inactive,
  );

  // Deliberately excludes expiresAt. This is what decides whether a status
  // *change* is published, and a renewal that only moves the date must not
  // be announced as a change of state -- every listener treats an event as
  // "premium turned on or off".
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

/// A consumable (non-subscription) product was bought. RevenueCat doesn't
/// model consumables as entitlements, so this cannot come from an
/// entitlement diff.
///
/// Raised for every ticket purchase RevenueCat knows about, every time the
/// customer info is read -- not once, at the moment of buying. Crediting
/// used to hang on that single moment: the store took the money, the app
/// emitted this, and whatever happened next had one chance to land. Four
/// purchases credited one (PM, 2026-08-21). What makes repeating it safe is
/// [transactionId] -- the credit is recorded against it, so the second
/// telling changes nothing, and the first one that never landed is picked
/// up on the next launch.
class ConsumableProductPurchased extends PurchaseEvent {
  const ConsumableProductPurchased(this.productId, this.transactionId);

  final String productId;

  /// Identifies this one purchase, for as long as RevenueCat remembers it.
  final String transactionId;

  @override
  String toString() => 'ConsumableProductPurchased($productId, $transactionId)';
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
