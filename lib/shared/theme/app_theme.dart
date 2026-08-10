import 'package:flutter/material.dart';

/// Warm brand seed color sampled from the wanote logo/mascot artwork (the
/// wordmark's dark cocoa-brown fill). Material 3's `ColorScheme.fromSeed`
/// derives the entire palette (primary/secondary/tertiary, and critically
/// `surface`/`scaffoldBackgroundColor`, which default to it) from this one
/// value, so every screen's buttons/chips/containers/background land in the
/// same warm brown/tan/peach family as the logo without needing per-widget
/// color overrides.
const Color wanoteBrandSeed = Color(0xFF603820);

/// Deliberately leaves `pageTransitionsTheme` alone, so every platform keeps
/// its own navigation animation: Android's predictive back gesture and iOS's
/// interactive edge-swipe-back are both platform behaviours users expect, and
/// both live in those defaults.
///
/// This was briefly overridden to make every transition instant, after
/// screens were seen fading out and leaving a smear of themselves behind. That
/// was observed in iOS *Safari* -- Flutter web composites its canvas
/// differently from a native Metal/Impeller surface, so it is very likely a
/// web-only artefact. The app ships natively, so rather than trade away two
/// platform gestures for a symptom that may not exist there, the decision (PM)
/// is to check on a device first. The implementation is in git if it turns out
/// to be needed: see 8266922 and 47b5990.
ThemeData buildWanoteTheme() {
  return ThemeData(colorSchemeSeed: wanoteBrandSeed, useMaterial3: true);
}
