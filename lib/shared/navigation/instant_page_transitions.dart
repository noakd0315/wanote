import 'package:flutter/material.dart';

/// A page transition that does not animate at all: the new screen is simply
/// there.
///
/// PM report: screens faded out and slid away when navigating, and on a phone
/// the outgoing screen left a visible smear behind — "全画面の情報が残った
/// 残像". Switching tabs from the bottom nav bar has never done that, because
/// that swaps an `IndexedStack` index instead of pushing a route, so the two
/// ways of leaving a screen looked nothing alike.
///
/// Both the durations and [buildTransitions] matter. Returning `child`
/// unchanged removes the animation from the incoming page, but the *outgoing*
/// page runs its own transition driven by the new route's animation as a
/// secondary animation — so it only stops moving once the duration is zero
/// too. Restoring a non-zero duration here brings the reported smear straight
/// back.
///
/// Applied for every platform via [instantPageTransitionsTheme], which costs
/// Android's predictive-back gesture preview (that lives in
/// [PredictiveBackPageTransitionsBuilder], the default this replaces). The
/// app is being verified in a mobile browser where that gesture does not
/// apply; revisit if it ships as a native Android app.
class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Every platform, so the behaviour does not depend on which one the app is
/// judged on — Flutter web reports the host platform, so a phone browser
/// would otherwise pick up Android's or iOS's animated default.
const PageTransitionsTheme instantPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: InstantPageTransitionsBuilder(),
    TargetPlatform.iOS: InstantPageTransitionsBuilder(),
    TargetPlatform.macOS: InstantPageTransitionsBuilder(),
    TargetPlatform.windows: InstantPageTransitionsBuilder(),
    TargetPlatform.linux: InstantPageTransitionsBuilder(),
    TargetPlatform.fuchsia: InstantPageTransitionsBuilder(),
  },
);
