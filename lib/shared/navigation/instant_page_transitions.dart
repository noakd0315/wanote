import 'package:flutter/material.dart';

/// A page transition that does not animate at all: the new screen is simply
/// there.
///
/// PM report: screens faded out and slid away when navigating and, on a phone,
/// the outgoing screen left a visible smear of itself behind ("全画面の情報が
/// 残った残像"), while the bottom nav bar had always switched instantly.
///
/// Both the durations and [buildTransitions] matter. Returning `child`
/// unchanged removes the animation from the incoming page, but the *outgoing*
/// page runs its own transition driven by the new route's animation as a
/// secondary animation — so it only stops moving once the duration is zero
/// too.
///
/// Used for the platforms the app is not being shipped on. Android goes
/// through [InstantForwardPredictiveBackPageTransitionsBuilder] instead, so
/// that the back gesture keeps working.
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

/// Android's predictive-back transition, but with instant forward pushes.
///
/// Gets both of the things the PM asked for. [PredictiveBackPageTransitionsBuilder]
/// already branches internally: while the user is dragging the back gesture it
/// plays the predictive shared-element animation, and for *everything else* --
/// forward pushes, taps on the AppBar's back arrow -- it falls back to
/// [FadeForwardsPageTransitionsBuilder], which is precisely the fade-and-slide
/// that was reported. The two are driven by different durations, so zeroing
/// only the forward one makes pushes instant while leaving the back gesture
/// and its commit animation intact.
///
/// Requires `android:enableOnBackInvokedCallback="true"` in
/// AndroidManifest.xml (added alongside this) and Android 14+ at runtime;
/// below that the framework falls back to the fade, which the zero duration
/// then makes instant anyway.
///
/// NOT YET VERIFIED ON A DEVICE. There is no AVD on the dev machine, and the
/// original smear was only ever seen in a mobile *browser* -- Flutter web
/// composites its canvas differently from a native Impeller surface, so it may
/// well not reproduce natively at all. If it doesn't, dropping this class and
/// using the stock `PredictiveBackPageTransitionsBuilder` gives back the
/// standard Android feel; if it does, this is the fallback that keeps the
/// gesture.
class InstantForwardPredictiveBackPageTransitionsBuilder
    extends PredictiveBackPageTransitionsBuilder {
  const InstantForwardPredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  /// Left at the platform default: this is what the predictive back gesture
  /// animates over once the user commits it. Zeroing this too would snap the
  /// screen away mid-gesture, which is the opposite of what predictive back
  /// is for.
  @override
  Duration get reverseTransitionDuration => const Duration(
    milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
  );
}

/// Every platform gets an entry, so behaviour never depends on which one the
/// app is judged on.
///
/// iOS deliberately still uses the instant builder: its interactive
/// edge-swipe-back has the same tension as Android's predictive back and
/// wants the same treatment, but the app is only being taken to Android
/// devices so far, and guessing at Cupertino's gesture timings without a
/// device to check on would be worse than leaving it obviously consistent.
const PageTransitionsTheme instantPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android:
        InstantForwardPredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: InstantPageTransitionsBuilder(),
    TargetPlatform.macOS: InstantPageTransitionsBuilder(),
    TargetPlatform.windows: InstantPageTransitionsBuilder(),
    TargetPlatform.linux: InstantPageTransitionsBuilder(),
    TargetPlatform.fuchsia: InstantPageTransitionsBuilder(),
  },
);
