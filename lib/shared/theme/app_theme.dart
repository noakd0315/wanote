import 'package:flutter/material.dart';

/// Warm brand seed color sampled from the wanote logo/mascot artwork (the
/// wordmark's dark cocoa-brown fill). Material 3's `ColorScheme.fromSeed`
/// derives the entire palette (primary/secondary/tertiary, and critically
/// `surface`/`scaffoldBackgroundColor`, which default to it) from this one
/// value, so every screen's buttons/chips/containers/background land in the
/// same warm brown/tan/peach family as the logo without needing per-widget
/// color overrides.
const Color wanoteBrandSeed = Color(0xFF603820);

ThemeData buildWanoteTheme() {
  return ThemeData(colorSchemeSeed: wanoteBrandSeed, useMaterial3: true);
}
