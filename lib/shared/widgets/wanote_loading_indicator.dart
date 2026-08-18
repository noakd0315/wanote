import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// The app's loading state: the wanote mark, breathing, with a word under it.
///
/// A plain spinner is the same one every Flutter app shows, and this app
/// makes the owner wait on things that take a real moment -- an AI answer,
/// an OCR scan, a photo upload. Those seconds are some of the most-looked-at
/// in the app, so they may as well be the app's.
///
/// **Never rotates** (PM instruction, 2026-08-18). The mark has a definite
/// upright orientation, and spinning it reads as broken rather than busy.
/// It fades and scales instead -- enough motion to say "working", none of it
/// angular.
///
/// Sized from the space it is given rather than a fixed number, so the same
/// widget can be the full-screen loading state the PM asked for (a mark
/// about as big as Home's) and still fit a 160px image slot without
/// overflowing it.
///
/// Only for waits that own the space they are in. A spinner inside a button
/// stays a spinner -- the mark is unreadable at that size, and a pulsing
/// blob in a button looks like a rendering fault.
class WanoteLoadingIndicator extends StatefulWidget {
  const WanoteLoadingIndicator({super.key, this.size});

  /// Fixed width for the mark. Null lets it size itself to the available
  /// space, which is what the full-screen case wants.
  final double? size;

  /// The common case: centered in whatever space is available.
  static Widget centered({double? size}) =>
      Center(child: WanoteLoadingIndicator(size: size));

  @override
  State<WanoteLoadingIndicator> createState() => _WanoteLoadingIndicatorState();
}

class _WanoteLoadingIndicatorState extends State<WanoteLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How big the mark can be here.
  ///
  /// Home shows the mark at 75% of the screen's width. This aims at the same
  /// impression without matching the number: the label sits underneath, and
  /// the pair has to stay comfortably inside the space, so the height is
  /// what usually decides it.
  double _resolveSize(BoxConstraints constraints) {
    if (widget.size != null) return widget.size!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    var size = screenWidth * 0.5;
    if (constraints.hasBoundedWidth) {
      size = math.min(size, constraints.maxWidth * 0.8);
    }
    if (constraints.hasBoundedHeight) {
      // Leaves room for the label and its gap.
      size = math.min(size, math.max(constraints.maxHeight - 44, 24));
    }
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _resolveSize(constraints);
        return Semantics(
          liveRegion: true,
          label: l10n.commonLoadingLabel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Opacity(
                  opacity: 0.45 + (_pulse.value * 0.55),
                  child: Transform.scale(
                    scale: 0.92 + (_pulse.value * 0.08),
                    child: child,
                  ),
                ),
                child: Image.asset(
                  'assets/images/wanote_icon.png',
                  width: size,
                  height: size,
                  // If the asset is ever missing, waiting must still look
                  // like waiting rather than like a broken image.
                  errorBuilder: (context, error, stackTrace) =>
                      SizedBox.square(dimension: size),
                ),
              ),
              const SizedBox(height: 8),
              // Excluded from semantics: the Semantics above already
              // announces this, and without this the label would be read
              // out twice.
              ExcludeSemantics(
                child: Text(
                  l10n.commonLoadingLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
