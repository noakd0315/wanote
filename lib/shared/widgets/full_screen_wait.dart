import 'package:flutter/material.dart';

import 'wanote_loading_indicator.dart';

/// A wait that covers the screen.
///
/// Deliberately opaque enough to read as "busy" rather than as a dimmed
/// version of the form: what is on screen is usually what the answer is
/// being generated from, and editing it mid-request would leave the reply
/// describing something that is no longer there.
///
/// Shared by all three AI screens. They asked the same thing of the owner --
/// wait while this is written -- and showed it three different ways: a full
/// cover here, a small indicator in the middle of the report, a spinner
/// inside the consultation's button (PM, 2026-08-23: ローディングを給餌量AIに
/// 合わせること).
///
/// Place inside a [Stack] whose other child is the screen body.
class FullScreenWait extends StatelessWidget {
  const FullScreenWait({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          child: WanoteLoadingIndicator.centered(),
        ),
      ),
    );
  }
}
