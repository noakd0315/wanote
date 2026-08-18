import 'dart:async';

import 'package:flutter/material.dart';

/// A black sheet laid over the whole app while an interstitial is on screen.
///
/// The ad does not cover the status bar, so a strip of this app stayed
/// visible above it: cream, against the ad's black letterbox. That strip is
/// what made the ad look like it was sliding up over the app rather than
/// replacing it (PM report). Repainting the status bar was tried first and
/// changed nothing on the device.
///
/// So instead of trying to reach around the ad, this covers what shows
/// through: whatever the ad leaves uncovered is ours, and ours is now black
/// to match. The ad's own letterboxing belongs to the SDK and cannot be
/// changed from here -- but it no longer has a cream edge against it.
///
/// Nothing here can fail loudly. If the overlay cannot be inserted, the ad
/// still shows; the app is never held up by its own cosmetics.
///
/// And it takes itself down. This is an opaque sheet over the entire app
/// that swallows every touch, put up for a *cosmetic* reason -- so it must
/// not depend on anyone remembering to remove it. Twice now the app has
/// been reported unusable because an ad did not appear and nothing called
/// [hide] (PM, 2026-08-18). The timer below is the guarantee that cannot be
/// undone by a bug somewhere else.
class AdBackdrop {
  AdBackdrop(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  OverlayEntry? _entry;
  Timer? _selfDestruct;

  /// The longest this may cover the app, whatever anyone else does.
  ///
  /// Comfortably longer than a person spends on an interstitial, so it
  /// never cuts one short; short enough that a stuck one is an annoyance
  /// rather than a reason to force-quit.
  static const Duration maxLifetime = Duration(minutes: 2);

  void show() {
    if (_entry != null) return;
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    final entry = OverlayEntry(
      // Not opaque: an opaque overlay stops the routes beneath it building,
      // and the screen underneath has to be intact the moment the ad closes.
      builder: (_) => const ColoredBox(
        color: Color(0xFF000000),
        child: SizedBox.expand(),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
    _selfDestruct = Timer(maxLifetime, hide);
  }

  void hide() {
    _selfDestruct?.cancel();
    _selfDestruct = null;
    _entry?.remove();
    _entry = null;
  }
}

/// The app's navigator, so the backdrop can reach the overlay from code that
/// has no BuildContext of its own -- AdManager is called from screens, but
/// the ad outlives the frame it was triggered from.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
