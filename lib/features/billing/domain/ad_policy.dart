import 'billing_models.dart';

/// Pure decision of whether ads should show for the current account, per
/// spec 8.1 ("広告表示は無料版のみに制御") and the 8.2 product table (only
/// premium_monthly/premium_yearly list "広告非表示" as a perk — the
/// ai_tickets_* consumables do not affect ad display at all).
///
/// Takes an [EntitlementState] rather than a raw bool so the transitional
/// "we haven't heard from RevenueCat yet" state is representable and can't
/// be silently confused with "confirmed not premium".
///
/// Decision for [EntitlementState.unknown] (app just launched / RevenueCat
/// customer info hasn't resolved yet): **ads are hidden**. We only turn ads
/// on once we've positively confirmed the account is not premium. The
/// alternative — showing ads by default and hiding them once premium is
/// confirmed — would flash an ad at paying subscribers during that loading
/// window, which is worse than a free user seeing a slightly delayed first
/// ad. This is a deliberate product trade-off, not a RevenueCat requirement.
class AdPolicy {
  const AdPolicy(this.premiumState);

  final EntitlementState premiumState;

  factory AdPolicy.fromStatus(PremiumStatus status) =>
      AdPolicy(status.state);

  /// True only once premium status is confirmed inactive. False both when
  /// the account is an active subscriber and while status is still
  /// [EntitlementState.unknown].
  bool get shouldShowAds => premiumState == EntitlementState.inactive;

  bool get shouldShowBanner => shouldShowAds;

  bool get shouldShowInterstitial => shouldShowAds;
}
