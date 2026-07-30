/// Runtime configuration for the billing feature.
///
/// Per wanote/.claude/CLAUDE.md ("APIキー・シークレットはコードに直書きせず
/// 環境変数化"), the RevenueCat public API key is never hardcoded here. It
/// must be supplied at build time, e.g.:
///
///   flutter run --dart-define=REVENUECAT_API_KEY=appl_xxxxxxxxxxxx
///
/// or via a `--dart-define-from-file` env json. [revenueCatApiKey] is empty
/// by default, which [RevenueCatBillingRepository.configure] treats as "not
/// configured yet" and skips calling `Purchases.configure` entirely — so the
/// app can still build/run/test before the PM has provisioned RevenueCat.
///
/// IMPORTANT (see task handoff notes): as of this writing the RevenueCat
/// dashboard has not been set up yet (no products, entitlements, or API
/// keys registered). This constant MUST be populated by the PM's own
/// RevenueCat project before billing can work on a real device.
class BillingConfig {
  const BillingConfig._();

  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => revenueCatApiKey.isNotEmpty;
}
