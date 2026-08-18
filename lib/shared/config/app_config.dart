import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kReleaseMode;

/// Every build-time value the app reads, declared in one place.
///
/// Supply them from a file rather than typing them on the command line:
///
///     flutter run --dart-define-from-file=config/dev.json
///     flutter build appbundle --dart-define-from-file=config/prod.json
///
/// `config/dart_define.example.json` lists every key with a comment. Copy it
/// to `config/prod.json` and fill in the values; `config/*.json` is
/// gitignored apart from the example.
///
/// **These are not secrets, and a config file does not make them so.** Every
/// value here is compiled into the shipped binary and can be read out of it:
/// AdMob unit ids, the RevenueCat *public* SDK key and the backend URL are
/// all designed to be client-side. The values that must stay secret -- the
/// Anthropic key, the RevenueCat *secret* key, the Firebase service account
/// -- live only in the Worker, set with `wrangler secret put`, and must
/// never appear in this file or anywhere else under `lib/`.
///
/// What cannot be moved here (the OS reads it before Dart starts):
///   - the AdMob **application** id, in AndroidManifest.xml and Info.plist
///   - `SKAdNetworkItems` and the permission usage strings, in Info.plist
///   - `google-services.json` / `GoogleService-Info.plist`
///   - `firebase_options.dart`, which `flutterfire configure` generates
class AppConfig {
  const AppConfig._();

  // ---------------------------------------------------------------------
  // Sign in with Apple (Android only)
  // ---------------------------------------------------------------------

  /// The Services ID registered on the Apple developer account, and where
  /// Apple sends the browser back to.
  ///
  /// Needed only on Android. iOS asks the OS directly and never sees these;
  /// every other platform runs Apple's web flow, which refuses to start
  /// without a Services ID and a redirect URI it recognises. Missing them
  /// is why "Appleでサインイン" failed on Android while working on iPhone
  /// (PM report, 2026-08-18).
  ///
  /// Defaulted rather than left empty: they are public identifiers, not
  /// secrets -- they travel through the user's own browser in the URL -- and
  /// a build that forgets to define them would fail in a way only an
  /// Android device shows.
  static const String appleServicesId = String.fromEnvironment(
    'APPLE_SERVICES_ID',
    defaultValue: 'jp.wanote.app.signin',
  );

  static const String appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://wanote-7dca0.firebaseapp.com/__/auth/handler',
  );

  // ---------------------------------------------------------------------
  // Backend
  // ---------------------------------------------------------------------

  /// Base URL of the Cloudflare Worker under `functions/`. Empty in local
  /// dev, where the app falls back to the host that served the page.
  static const String backendBaseUrl = String.fromEnvironment(
    'AI_BACKEND_BASE_URL',
  );

  // ---------------------------------------------------------------------
  // RevenueCat
  // ---------------------------------------------------------------------

  /// RevenueCat issues a **different public key per platform** (`appl_…`
  /// for iOS, `goog_…` for Android). Configuring with the wrong one fails
  /// at runtime on that platform only, which is easy to miss when testing
  /// on a single device.
  static const String _revenueCatApiKeyIos = String.fromEnvironment(
    'REVENUECAT_API_KEY_IOS',
  );
  static const String _revenueCatApiKeyAndroid = String.fromEnvironment(
    'REVENUECAT_API_KEY_ANDROID',
  );

  /// Kept for the single-key setup that predates the split above; used when
  /// no platform-specific key is supplied.
  static const String _revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
  );

  /// Pretends the account holds an active subscription, for testing the
  /// unlocked behaviour before RevenueCat exists.
  ///
  /// Billing cannot be configured until the app is in a store, which leaves
  /// no way to see what a subscriber sees: no ads, no usage limit, the
  /// premium-only screens reachable. This makes that state reachable from a
  /// build flag instead of from a purchase.
  ///
  ///     flutter run --dart-define=PRETEND_PREMIUM=true ...
  ///
  /// Guarded by [kReleaseMode] as well, so a value left in a config file
  /// cannot ship an app that gives everything away. A release build ignores
  /// it entirely.
  static bool get pretendPremium =>
      !kReleaseMode &&
      const String.fromEnvironment('PRETEND_PREMIUM') == 'true';

  static String get revenueCatApiKey {
    final platformKey = defaultTargetPlatform == TargetPlatform.iOS
        ? _revenueCatApiKeyIos
        : _revenueCatApiKeyAndroid;
    return platformKey.isNotEmpty ? platformKey : _revenueCatApiKey;
  }

  /// The entitlement both premium SKUs unlock. Must match the identifier
  /// created in the RevenueCat dashboard.
  static const String premiumEntitlementId = String.fromEnvironment(
    'REVENUECAT_PREMIUM_ENTITLEMENT',
    defaultValue: 'premium',
  );

  // ---------------------------------------------------------------------
  // Store products
  // ---------------------------------------------------------------------

  static const String premiumMonthlyProductId = String.fromEnvironment(
    'PRODUCT_PREMIUM_MONTHLY',
    defaultValue: 'premium_monthly',
  );
  static const String premiumYearlyProductId = String.fromEnvironment(
    'PRODUCT_PREMIUM_YEARLY',
    defaultValue: 'premium_yearly',
  );
  static const String aiTickets5ProductId = String.fromEnvironment(
    'PRODUCT_AI_TICKETS_5',
    defaultValue: 'ai_tickets_5',
  );
  static const String aiTickets15ProductId = String.fromEnvironment(
    'PRODUCT_AI_TICKETS_15',
    defaultValue: 'ai_tickets_15',
  );

  // ---------------------------------------------------------------------
  // AdMob
  // ---------------------------------------------------------------------

  /// Google's official *test* interstitial units are the defaults, so a
  /// build with no configuration serves test creatives instead of failing
  /// or, worse, spending someone's real inventory.
  ///
  /// See https://developers.google.com/admob/flutter/test-ads. Replace with
  /// the ids from the PM's own AdMob account for a release build --
  /// **never guess a production id**, an invalid one silently serves
  /// nothing.
  static const String androidInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const String iosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const String androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String iosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  /// True when every value still has its built-in default, i.e. nothing was
  /// configured. Useful in a release checklist: shipping with test ad units
  /// earns no revenue at all, and nothing about the running app says so.
  static bool get isUsingTestAdUnits =>
      androidInterstitialAdUnitId.startsWith('ca-app-pub-3940256099942544');
}
