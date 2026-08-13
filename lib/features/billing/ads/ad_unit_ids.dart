import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../../shared/config/app_config.dart';

/// Ad unit IDs for `google_mobile_ads`, resolved per platform.
///
/// The values themselves live in [AppConfig] so every configurable id sits
/// in one file (see `config/dart_define.example.json`). With nothing
/// configured they are Google's official *test* units, which always serve
/// test creatives -- safe, and better than a wrong production id, which
/// silently serves nothing at all.
///
/// **Shipping with the test units earns no revenue and the running app
/// gives no sign of it.** [AppConfig.isUsingTestAdUnits] is there to be
/// checked before a release.
///
/// Deliberately not `dart:io`: importing it breaks the web build, and the
/// app is developed on web.
class AdUnitIds {
  const AdUnitIds._();

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  static String get banner =>
      _isIos ? AppConfig.iosBannerAdUnitId : AppConfig.androidBannerAdUnitId;

  static String get interstitial => _isIos
      ? AppConfig.iosInterstitialAdUnitId
      : AppConfig.androidInterstitialAdUnitId;
}
