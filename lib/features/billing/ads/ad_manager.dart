import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../shared/config/app_config.dart';
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
    // AppConfig.isUsingTestAdUnits existed but nothing ever read it, so the
    // one guard against shipping with Google's test units did nothing
    // (found 2026-08-20). Shipping like that serves ads that earn nothing,
    // and the running app looks completely normal -- there is no other sign.
    //
    // A log, not a dialog or a banner: it has to be findable when someone
    // goes looking, without putting anything in front of the owner.
    if (AppConfig.isUsingTestAdUnits) {
      _log(
        'USING GOOGLE TEST AD UNITS -- ads will earn no revenue. '
        'Set ADMOB_* in config/prod.json before a production release.',
      );
    }
    await _requestTrackingAuthorizationIfNeeded();
    await MobileAds.instance.initialize();
  }

  /// Asks iOS for permission to use the advertising identifier.
  ///
  /// Required from iOS 14.5: without it the IDFA is simply unavailable, so
  /// ads still show but are untargeted and worth less. `google_mobile_ads`
  /// has no API for this -- it is a separate framework -- which is how the
  /// call came to be missing while `NSUserTrackingUsageDescription`,
  /// PLAN_ads.md's design and the privacy policy all assumed it was there
  /// (found 2026-08-18 while checking the policy against the code).
  ///
  /// Immediately before initializing the ads SDK, per PLAN_ads.md: asking
  /// at launch, before the owner has seen what the app is, gets refused.
  ///
  /// Asked once, ever. `notDetermined` is the only state where the system
  /// will show anything; afterwards the answer lives in iOS Settings, and
  /// calling again is a silent no-op rather than a second prompt.
  ///
  /// Refusal changes nothing about the app. It is not a gate: ads keep
  /// working, and every feature stays available. So nothing here reports a
  /// failure -- there is no decision anyone needs to take from it.
  static Future<void> _requestTrackingAuthorizationIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) {
        _log('tracking authorization already answered: ${status.name}');
        return;
      }
      final result =
          await AppTrackingTransparency.requestTrackingAuthorization();
      _log('tracking authorization: ${result.name}');
    } catch (error, stackTrace) {
      developer.log(
        'Could not ask for tracking authorization',
        name: 'AdManager',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
          _log('loaded and ready');
          _isLoadingInterstitial = false;
          _loadedInterstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _log('failed to load: $error');
          _isLoadingInterstitial = false;
          _loadedInterstitial = null;
        },
      ),
    );
  }

  /// Shows a preloaded interstitial if [AdPolicy.shouldShowInterstitial] is
  /// true and one is ready; otherwise does nothing (never blocks the caller
  /// waiting on an ad to load).
  ///
  /// **Completes when the ad is dismissed**, not when it appears. `show()`
  /// alone returns as soon as the ad is on screen, which meant a caller's
  /// next line ran behind a full-screen ad -- and that is exactly where the
  /// "saved" message was going. It was shown, and covered, and gone by the
  /// time the owner got back (PM: "一度も見れませんでした").
  /// Returns whether an ad actually reached the screen, so a caller can
  /// decide whether the attempt is worth repeating. False covers every
  /// reason alike: premium, nothing loaded, or a presentation the OS
  /// refused.
  Future<bool> maybeShowInterstitial() async {
    if (!_supported) {
      _log('skipped: platform has no ads');
      return false;
    }
    if (!_currentPolicy().shouldShowInterstitial) {
      _log('skipped: policy says no ad right now');
      return false;
    }
    final ad = _loadedInterstitial;
    if (ad == null) {
      // The most likely reason nothing appears. One interstitial is held at
      // a time and the refill is a network fetch, so a second trigger
      // shortly after the first finds the shelf empty.
      _log(
        'skipped: none loaded '
        '(loading=$_isLoadingInterstitial)',
      );
      return false;
    }

    _loadedInterstitial = null;
    var reachedTheScreen = false;
    final dismissed = Completer<void>();
    // Armed below. Cancelled the moment the ad reports itself on screen, so
    // a watched ad is never cut short.
    Timer? appearanceWatchdog;
    void finish() {
      appearanceWatchdog?.cancel();
      appearanceWatchdog = null;
      _backdrop.hide();
      if (!dismissed.isCompleted) dismissed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        // It is really on screen, so the backdrop is doing its job and the
        // only thing left to wait for is a person closing it.
        _log('showed');
        reachedTheScreen = true;
        appearanceWatchdog?.cancel();
        appearanceWatchdog = null;
      },
      onAdDismissedFullScreenContent: (ad) {
        _log('dismissed');
        finish();
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log('failed to show: $error');
        finish();
        ad.dispose();
        preloadInterstitial();
      },
    );
    _backdrop.show();
    // The backdrop absorbs every touch -- that is what makes it a backdrop.
    // So it must never be able to outlive the ad it is backing. If the ad
    // has not reported itself on screen shortly after show(), assume it is
    // not coming and let the app go: an ad that failed to appear is a
    // missed impression, while a black sheet nobody can dismiss is a dead
    // app (PM report, 2026-08-18: "中間レイヤーは発動しているので、その
    // あとの操作ができない").
    appearanceWatchdog = Timer(_appearanceTimeout, () {
      _log('never appeared within $_appearanceTimeout; releasing the app');
      finish();
    });
    // Started, not awaited.
    //
    // show() returning tells us nothing useful -- the callbacks above are
    // what report the ad's life -- and awaiting it puts the SDK on the path
    // between here and the line that waits for dismissal. When show() did
    // not return, that line was never reached, so the caller waited on a
    // future nothing would ever complete (PM: OCR still stuck, 2026-08-18).
    unawaited(ad.show());
    // A callback that never fires would strand the caller mid-save, so the
    // wait has a ceiling. Generous: this is an upper bound on a stuck SDK,
    // not a limit on how long someone may look at an ad.
    await dismissed.future.timeout(
      const Duration(minutes: 2),
      onTimeout: finish,
    );
    return reachedTheScreen;
  }

  /// How long an ad gets to appear before the backdrop gives up on it.
  ///
  /// Presentation is local -- the creative is already downloaded -- so this
  /// is the SDK handing a view controller to the OS, not a network round
  /// trip. Long enough to absorb a slow frame, short enough that a failure
  /// reads as a flicker rather than a hang.
  static const Duration _appearanceTimeout = Duration(seconds: 3);

  /// One tag for the whole ad path, so a device log filtered to `AdManager`
  /// tells the whole story of an impression that did not happen.
  ///
  /// Ads fail silently by design here -- nothing about a missing one is
  /// visible on screen -- which left "no ad appeared" indistinguishable
  /// from a dozen different causes across three rounds of reports
  /// (2026-08-18). These lines are what makes the next report answerable.
  static void _log(String message) => developer.log(message, name: 'AdManager');

  void dispose() {
    _loadedInterstitial?.dispose();
    _loadedInterstitial = null;
  }
}
