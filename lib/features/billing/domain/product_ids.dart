/// RevenueCat product identifiers, copied verbatim from spec 8.2's product
/// table. Every purchase call-site should reference these constants instead
/// of hardcoding the strings, so a typo can't silently create a mismatch
/// against the SKUs the PM registers in the RevenueCat/App Store/Play
/// Console dashboards.
class ProductIds {
  const ProductIds._();

  /// Auto-renewing subscription. Ads hidden + AI unlimited + AI report
  /// (spec 8.2).
  static const String premiumMonthly = 'premium_monthly';

  /// Auto-renewing subscription, same perks as [premiumMonthly] at a
  /// discounted annual price (spec 8.2).
  static const String premiumYearly = 'premium_yearly';

  /// Consumable IAP: credits 5 AI-consultation tickets.
  static const String aiTickets5 = 'ai_tickets_5';

  /// Consumable IAP: credits 15 AI-consultation tickets.
  static const String aiTickets15 = 'ai_tickets_15';

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
/// ASSUMPTION: the spec doesn't name an entitlement identifier explicitly
/// (section 8.2 only lists product IDs), so we assume the PM will configure
/// a single entitlement called "premium" in the RevenueCat dashboard and
/// attach both premium_monthly and premium_yearly to it. If the PM chooses a
/// different identifier when setting up RevenueCat, update this one constant.
class EntitlementIds {
  const EntitlementIds._();

  static const String premium = 'premium';
}
