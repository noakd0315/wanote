import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../shared/services/ai_usage_repository.dart';
import '../domain/ad_policy.dart';
import '../domain/ad_trigger.dart';
import '../domain/billing_models.dart';
import 'ad_manager.dart';

/// The single thing screens call to show an ad.
///
/// Screens name a [AdTrigger] and, for AI actions, which wallet paid; every
/// decision about whether an ad actually appears lives here and in
/// [AdTriggerPolicy]. Screens never touch [AdManager] or [AdPolicy]
/// directly, so "when does an ad show?" has one answer rather than one per
/// screen.
class AdGate {
  // Private initializing formals, passed by their public names
  // (`manager:` and so on) at the call site -- same idiom as AuthController.
  AdGate({
    required this._manager,
    required this._premiumStatus,
    this.policy = const AdTriggerPolicy(),
  });

  final AdManager _manager;
  final PremiumStatus Function() _premiumStatus;
  final AdTriggerPolicy policy;

  /// Shows an interstitial for [trigger], if the rules allow one and an ad
  /// happens to be loaded.
  ///
  /// Never waits on a network load and never throws: an action must finish
  /// at the same speed whether or not there is an ad to show. A trigger that
  /// finds nothing loaded simply passes.
  ///
  /// [aiUsageSource] must be read *before* the AI call is recorded -- after
  /// that the balance has moved, and the last ticket spent would look like
  /// no ticket at all. See [AdTriggerPolicy].
  Future<void> maybeShow(
    AdTrigger trigger, {
    AiUsageSource? aiUsageSource,
  }) async {
    if (!policy.shouldShowAd(
      trigger: trigger,
      premiumStatus: _premiumStatus(),
      aiUsageSource: aiUsageSource,
    )) {
      return;
    }
    try {
      await _manager.maybeShowInterstitial();
    } catch (error, stackTrace) {
      // Every call site sits next to something the owner actually wanted --
      // a saved record, an AI answer. An ad network having a bad day must
      // never turn into that action appearing to fail.
      developer.log(
        'Could not show an interstitial',
        name: 'AdGate',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Fetches an ad in the background so one is ready when a trigger fires.
  /// Called on sign-in and when a screen that can trigger one opens.
  Future<void> preload() => _manager.preloadInterstitial();
}

/// The [AdGate] for the surrounding app shell, or null when there isn't one.
///
/// Nullable on purpose. Screens are also built directly in widget tests and
/// reachable from the launch gate, neither of which sits under HomeShell's
/// provider -- and a missing ad gate should mean "no ads here", never a
/// crash on a screen the owner is trying to use.
///
/// Call it before the first `await`: reading a BuildContext afterwards is a
/// use-after-dispose hazard.
AdGate? adGateOf(BuildContext context) {
  try {
    return Provider.of<AdGate>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}
