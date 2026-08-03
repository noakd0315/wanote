import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative dog-silhouette pattern shown faintly behind a screen's real
/// content (PM request: "各画面の背景に犬のシルエットをちりばめたい").
///
/// The 10 source images are plain white silhouettes on transparent
/// backgrounds (sliced from a larger reference sheet) -- [ColorFilter.mode]
/// with `BlendMode.srcIn` recolors each one uniformly to [tint] (the brand
/// color by default) regardless of that source color, so this widget
/// doesn't need per-asset color variants.
///
/// Positions/sizes/rotations are a fixed hand-placed layout rather than
/// randomized at build time -- randomizing per rebuild would make the
/// pattern visibly jump around every time the screen rebuilds (e.g. on
/// every setState), which reads as a bug rather than decoration.
class DogSilhouetteBackground extends StatelessWidget {
  const DogSilhouetteBackground({super.key, this.opacity = 0.05, this.tint});

  /// Kept very low by default -- this sits behind real content and must
  /// never compete with it for attention or hurt text contrast.
  final double opacity;

  /// Defaults to the theme's primary (the same warm brown the logo/theme
  /// seed uses) so the pattern always matches the active color scheme.
  final Color? tint;

  static const _assets = [
    'assets/images/dogs/dog_01_standing.png',
    'assets/images/dogs/dog_02_greyhound.png',
    'assets/images/dogs/dog_03_corgi.png',
    'assets/images/dogs/dog_04_dachshund.png',
    'assets/images/dogs/dog_05_sitting.png',
    'assets/images/dogs/dog_06_pomeranian.png',
    'assets/images/dogs/dog_07_running.png',
    'assets/images/dogs/dog_08_stretch.png',
    'assets/images/dogs/dog_09_sitting_poodle.png',
    'assets/images/dogs/dog_10_howling.png',
  ];

  /// (asset index, left-fraction, top-fraction, width in logical px,
  /// rotation in turns). Fractions are of the available space, so the
  /// scattered layout scales to whatever size the screen behind it is.
  static const List<(int, double, double, double, double)> _layout = [
    (0, 0.06, 0.04, 92, -0.03),
    (3, 0.72, 0.03, 68, 0.04),
    (6, 0.42, 0.14, 82, -0.02),
    (2, 0.88, 0.20, 64, 0.05),
    (5, 0.12, 0.27, 76, 0.02),
    (8, 0.58, 0.32, 86, -0.04),
    (1, 0.02, 0.45, 70, 0.03),
    (9, 0.78, 0.43, 90, -0.02),
    (4, 0.33, 0.55, 74, 0.03),
    (7, 0.63, 0.60, 80, -0.03),
    (0, 0.08, 0.68, 68, 0.02),
    (6, 0.83, 0.72, 64, -0.05),
    (2, 0.38, 0.81, 88, 0.02),
    (5, 0.68, 0.88, 74, -0.02),
    (3, 0.13, 0.89, 64, 0.04),
  ];

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (!width.isFinite || !height.isFinite) {
            return const SizedBox.shrink();
          }
          return ClipRect(
            child: Stack(
              children: [
                for (final (assetIndex, leftF, topF, size, turns) in _layout)
                  Positioned(
                    left: leftF * width,
                    top: topF * height,
                    child: Transform.rotate(
                      angle: turns * 2 * math.pi,
                      child: Opacity(
                        opacity: opacity,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                          child: Image.asset(_assets[assetIndex], width: size),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
