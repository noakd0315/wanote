import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/ad_policy.dart';
import 'ad_backdrop.dart';
import 'ad_unit_ids.dart';

/// Thin wrapper around `google_mobile_ads` for interstitial ads, gated by
/// [AdPolicy] (spec 8.1: ads for free users only). Banner ads are handled by
/// [BannerAdWidget] instead, since they need a widget slot to mount into.
///
/// Interstitial loading is best-effort: failures are swallowed (logged via
/// [onAdFailedToLoad] callback only) so a flaky ad network never breaks app
/// navigation. Call [maybeShowInterstitial] at natural break points (e.g.
/// after saving a health record) — it silently does nothing for premium
/// users or while an ad is already loading/showing.
class AdManager {
  AdManager({required AdPolicy Function() currentPolicy, bool? supported})
    // ignore: prefer_initializing_formals
    : _currentPolicy = currentPolicy,
      _supported = supported ?? platformSupported;

  final AdPolicy Function() _currentPolicy;

  /// Covers whatever the ad leaves showing. See [AdBackdrop].
  final AdBackdrop _backdrop = AdBackdrop(appNavigatorKey);

  /// Injected only by tests, which run on the host platform.
  final bool _supported;

  InterstitialAd? _loadedInterstitial;
  bool _isLoadingInterstitial = false;

  /// google_mobile_ads ships no web implementation, so every call here is a
  /// no-op on web -- which is where the app is developed. Without this,
  /// initializing ads at startup would throw on every local run.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Safe to call anywhere: does nothing on a platform without ads.
  static Future<void> initialize() async {
    if (!platformSupported) return;
    await MobileAds.instance.initialize();
  }

  /// Pre-loads an interstitial so it's ready by the time
  /// [maybeShowInterstitial] is called. No-ops if ads shouldn't show right
  /// now, or one is already loaded/loading.
  Future<void> preloadInterstitial() async {
    if (!_supported) return;
    if (!_currentPolicy().shouldShowInterstitial) return;
    if (_loadedInterstitial != null || _isLoadingInterstitial) return;

    _isLoadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;
          _loadedInterstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _loadedInterstitial = null;
        },
      ),
    );
  }

  /// Shows a preloaded interstitial if [AdPolicy.shouldShowInterstitial] is
  /// true and one is ready; otherwise does nothing (never blocks the caller
  /// waiting on an ad to load).
  Future<void> maybeShowInterstitial() async {
    if (!_supported) return;
    if (!_currentPolicy().shouldShowInterstitial) return;
    final ad = _loadedInterstitial;
    if (ad == null) return;

    _loadedInterstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _backdrop.hide();
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _backdrop.hide();
        ad.dispose();
        preloadInterstitial();
      },
    );
    _backdrop.show();
    await ad.show();
  }

  void dispose() {
    _loadedInterstitial?.dispose();
    _loadedInterstitial = null;
  }
}
