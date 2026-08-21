import 'dart:async';

import '../domain/billing_models.dart';

/// Gets ads ready for a session: start the SDK, wait until premium status is
/// actually known, then fetch the first interstitial -- and keep fetching
/// one as the entitlement changes underneath.
///
/// This lives outside the app shell because the order of those steps is
/// load-bearing and got it wrong once. The shell builds its own repositories,
/// so the sequence could not be exercised in a test while it was inlined
/// there -- and the failure it produced was invisible: no crash, no log, just
/// an app where no ad ever appeared.
///
/// Returns a subscription the caller must cancel. Preparing once was not
/// enough: an account that is premium when the session starts fetches
/// nothing here, and when the plan later turns out to have lapsed -- a free
/// month running out, a resume re-reading the entitlement -- there was no
/// second attempt, so the session ran to its end with an empty shelf and no
/// ad for any trigger (PM, 2026-08-21).
Future<StreamSubscription<PremiumStatus>> prepareAds({
  required Future<void> Function() initializeSdk,
  required Stream<PremiumStatus> premiumStatusChanges,
  required PremiumStatus Function() currentPremiumStatus,
  required Future<void> Function() preload,
  Duration timeout = const Duration(seconds: 10),
}) async {
  // Every arrival at "inactive" *after* the session's first fetch. Before
  // that there is nothing to do: the SDK may not be up yet, and the first
  // fetch is the business of the sequence below.
  var readyForRefills = false;
  final refills = premiumStatusChanges.listen((status) {
    if (!readyForRefills) return;
    if (status.state != EntitlementState.inactive) return;
    // preload() itself declines when one is already loaded or the account
    // is premium, so this needs no condition beyond the state that brought
    // it here.
    unawaited(preload().catchError((_) {}));
  });

  // Subscribed before the first await, and that is the whole point.
  //
  // premiumStatusChanges is a broadcast stream: it keeps nothing for
  // listeners that arrive late. The status can be reported the instant
  // billing is configured -- immediately, when there is no RevenueCat key to
  // check -- while starting the ads SDK takes seconds. Subscribing after
  // that await meant the answer had already been delivered to nobody, the
  // wait below ran its full timeout, and preload was never reached.
  final confirmed = premiumStatusChanges
      .firstWhere((status) => status.state != EntitlementState.unknown)
      .timeout(timeout);
  try {
    await initializeSdk();
    // Only fetch once premium status is confirmed inactive, so a subscriber
    // never has an ad sitting loaded to flash at them.
    if (currentPremiumStatus().state == EntitlementState.unknown) {
      await confirmed;
    } else {
      // Already answered. The future is still live and would report its
      // timeout as an unhandled async error, so retire it explicitly.
      confirmed.ignore();
    }
    await preload();
    readyForRefills = true;
  } catch (_) {
    // Ads are best-effort from the first line. No ads this session; nothing
    // else about the session changes.
    confirmed.ignore();
  }
  return refills;
}
