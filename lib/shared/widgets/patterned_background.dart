import 'package:flutter/material.dart';

import 'dog_silhouette_background.dart';

/// An opaque page background carrying the dog-silhouette pattern.
///
/// Screens used to be transparent and let HomeShell's single background
/// show through from behind its Navigator. That works while a screen sits
/// still, and breaks the moment one is pushed: during the slide, a
/// transparent incoming route shows the outgoing route through itself, so
/// the old screen appears smeared across the new one (PM report,
/// 2026-08-18 -- 予防医療の一覧, 証明書の＋, プランをアップグレード).
///
/// Painting the background per screen makes every route opaque, which is
/// what a page transition assumes. The pattern is unchanged: same asset,
/// same tint, same fixed layout, so a screen looks the same as it did.
class PatternedBackground extends StatelessWidget {
  const PatternedBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Explicit rather than inherited: this is the layer that makes the
        // route opaque, so it cannot be left to whatever is behind it.
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        const DogSilhouetteBackground(),
        child,
      ],
    );
  }
}
