import 'package:flutter/material.dart';

/// A route that appears without sliding in.
///
/// The home shortcuts are meant to feel like switching tabs, not like
/// travelling somewhere. Three of the four do exactly that -- they change
/// the selected section, which swaps instantly. The fourth pushed a screen
/// instead, so pressing it slid a page across while its neighbours did not,
/// and the row of four buttons behaved two different ways (PM report,
/// 2026-08-17).
///
/// The destination here genuinely is a pushed screen: 給餌量 has no section
/// of its own to switch to. Removing the transition is what makes it look
/// like the ones that do.
class ShortcutRoute<T> extends PageRouteBuilder<T> {
  ShortcutRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
}
