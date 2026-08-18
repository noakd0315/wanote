import 'dart:async';
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
  const WanoteLoadingIndicator({super.key, this.size, this.delay = _default});

  /// Fixed width for the mark. Null lets it size itself to the available
  /// space, which is what the full-screen case wants.
  final double? size;

  /// How long to wait before appearing at all.
  ///
  /// Most loads finish in well under this: a Firestore stream with warm
  /// cache answers on the next frame or two. Showing the mark for those
  /// makes it flash on and off as a screen opens, which reads as a glitch
  /// rather than as loading (PM report, 2026-08-18: "画面が切り替わってから
  /// 一瞬ロードが見えたりする").
  ///
  /// So nothing is drawn for this long. Either the content arrives first
  /// and the indicator was never seen, or the wait is real and worth
  /// showing. Pass [Duration.zero] where the wait is known to be long and
  /// an immediate answer is wanted.
  final Duration delay;

  static const Duration _default = Duration(milliseconds: 300);

  /// The common case: centered in whatever space is available.
  static Widget centered({double? size, Duration delay = _default}) =>
      Center(child: WanoteLoadingIndicator(size: size, delay: delay));

  @override
  State<WanoteLoadingIndicator> createState() => _WanoteLoadingIndicatorState();
}

class _WanoteLoadingIndicatorState extends State<WanoteLoadingIndicator>
    with SingleTickerProviderStateMixin {
  // Created in initState, not as a lazy field initialiser. While the
  // indicator is inside its delay it never builds, so a lazy controller
  // would first be touched by dispose() -- and constructing a ticker there
  // looks up an ancestor on a deactivated element, which asserts.
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  /// False until [WanoteLoadingIndicator.delay] has passed.
  bool _visible = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.delay == Duration.zero) {
      _visible = true;
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The mark's height as a fraction of its width (900x614). Kept here
  /// rather than read from the image, which is only known once it decodes.
  static const double _markAspectRatio = 614 / 900;

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
      // `size` is a width, and the mark is wider than it is tall -- so the
      // height it will actually occupy is the width times the aspect ratio.
      // Leaves room for the label and its gap on top of that.
      final heightForMark = math.max(constraints.maxHeight - 40, 24);
      size = math.min(size, heightForMark / _markAspectRatio);
    }
    return size;
  }

  @override
  Widget build(BuildContext context) {
    // Takes no space either, so a short load does not nudge the layout on
    // its way past.
    if (!_visible) return const SizedBox.shrink();
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
                // Width only. The mark is 900x614, so forcing it into a
                // square box left empty space above and below the artwork
                // -- and the label, sitting 8px under the *box*, ended up
                // well clear of the picture (PM, 2026-08-18). Letting the
                // height follow the aspect ratio puts the box back around
                // the drawing.
                child: Image.asset(
                  'assets/images/wanote_icon.png',
                  width: size,
                  // If the asset is ever missing, waiting must still look
                  // like waiting rather than like a broken image.
                  errorBuilder: (context, error, stackTrace) =>
                      SizedBox(width: size, height: size * _markAspectRatio),
                ),
              ),
              const SizedBox(height: 4),
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
