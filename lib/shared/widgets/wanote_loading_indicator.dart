import 'package:flutter/material.dart';

/// The app's loading state: the wanote mark, breathing (PM request:
/// "ローディングをwanoteアイコンにしたい").
///
/// A plain spinner is the same one every Flutter app shows, and this app
/// makes the owner wait on things that take a real moment -- an AI answer,
/// an OCR scan, a photo upload. Those seconds are some of the most-looked-at
/// in the app, so they may as well be the app's.
///
/// Scale-and-fade rather than a rotation: the mark has a definite upright
/// orientation, and spinning it reads as broken rather than busy.
///
/// Only for waits that own the space they are in. A spinner inside a button
/// or a 16px slot stays a spinner -- the mark is unreadable at that size,
/// and a pulsing blob in a button looks like a rendering fault.
class WanoteLoadingIndicator extends StatefulWidget {
  const WanoteLoadingIndicator({super.key, this.size = 56});

  final double size;

  /// The common case: centered in whatever space is available.
  static Widget centered({double size = 56}) =>
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // The mark carries no meaning to a screen reader, and without this
      // the loading state would announce nothing at all -- the stock
      // indicator it replaces is labelled by the framework.
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Opacity(
          opacity: 0.45 + (_pulse.value * 0.55),
          child: Transform.scale(scale: 0.88 + (_pulse.value * 0.12), child: child),
        ),
        child: Image.asset(
          'assets/images/wanote_icon.png',
          width: widget.size,
          height: widget.size,
          // If the asset is ever missing, waiting must still look like
          // waiting rather than like a broken image.
          errorBuilder: (context, error, stackTrace) =>
              const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
