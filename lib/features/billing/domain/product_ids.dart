import '../../../shared/config/app_config.dart';

/// RevenueCat product identifiers, defaulting to spec 8.2's product table. Every purchase call-site should reference these constants instead
/// of hardcoding the strings, so a typo can't silently create a mismatch
/// against the SKUs the PM registers in the RevenueCat/App Store/Play
/// Console dashboards.
class ProductIds {
  const ProductIds._();

  /// Auto-renewing subscription. Ads hidden + AI unlimited + AI report
  /// (spec 8.2).
  static const String premiumMonthly = AppConfig.premiumMonthlyProductId;

  /// Auto-renewing subscription, same perks as [premiumMonthly] at a
  /// discounted annual price (spec 8.2).
  static const String premiumYearly = AppConfig.premiumYearlyProductId;

  /// Consumable IAP: credits 5 AI-consultation tickets.
  static const String aiTickets5 = AppConfig.aiTickets5ProductId;

  /// Consumable IAP: credits 15 AI-consultation tickets.
  static const String aiTickets15 = AppConfig.aiTickets15ProductId;

  static const List<String> all = [
    premiumMonthly,
    premiumYearly,
    aiTickets5,
    aiTickets15,
  ];

  static const List<String> subscriptions = [premiumMonthly, premiumYearly];

  static const List<String> consumables = [aiTickets5, aiTickets15];

  /// A store product id with Google Play's base-plan suffix removed.
  ///
  /// The two stores do not return the same string for the same product.
  /// Play appends the base plan that was actually bought; Apple does not:
  ///
  /// ```
  /// Apple  premium_monthly            ai_tickets_5
  /// Play   premium_monthly:monthly    ai_tickets_5
  /// ```
  ///
  /// (Confirmed against the real imports, PM 2026-08-20.) Comparing the raw
  /// string therefore matched on iOS and missed on Android, and the paywall
  /// fell through to the store's own title for every subscription.
  ///
  /// Splitting on `:` is safe: a product id cannot contain one. Play allows
  /// only lowercase letters, digits, `_` and `.`, and Apple is likewise
  /// restricted -- the colon is exactly why RevenueCat can use it as the
  /// separator.
  ///
  /// Applied to consumables too, even though tickets carry no suffix today.
  /// One-time products gained their own "purchase option" layer in 2026, and
  /// if Play ever starts appending it, crediting a ticket would silently
  /// stop working -- the owner would pay and receive nothing.
  static String baseId(String productId) => productId.split(':').first;
}

/// The RevenueCat entitlement identifier shared by both premium SKUs.
///
/// Defaults to "premium"; override with `REVENUECAT_PREMIUM_ENTITLEMENT` in
/// the config file if the dashboard uses a different identifier. Both
/// premium SKUs must be attached to it.
class EntitlementIds {
  const EntitlementIds._();

  static const String premium = AppConfig.premiumEntitlementId;
}
