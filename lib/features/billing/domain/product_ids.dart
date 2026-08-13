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
