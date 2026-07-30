import 'dart:io' show Platform;

/// Ad unit IDs for `google_mobile_ads`.
///
/// These are Google's official *test* ad unit IDs
/// (https://developers.google.com/admob/flutter/test-ads) — they always
/// serve test creatives and are safe to ship in debug builds, but they are
/// NOT real inventory. Real ad unit IDs must come from the PM's own AdMob
/// account (one app + one ad unit per placement, per platform) and be
/// swapped in here before this feature goes live. Do not replace these with
/// guessed/fabricated production IDs.
class AdUnitIds {
  const AdUnitIds._();

  static String get banner => Platform.isAndroid
      ? _androidTestBanner
      : Platform.isIOS
      ? _iosTestBanner
      : _androidTestBanner;

  static String get interstitial => Platform.isAndroid
      ? _androidTestInterstitial
      : Platform.isIOS
      ? _iosTestInterstitial
      : _androidTestInterstitial;

  static const String _androidTestBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBanner =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
}
