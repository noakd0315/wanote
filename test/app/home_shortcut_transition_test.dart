import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/navigation/instant_page_route.dart';

/// PM report: leaving Home via a shortcut made it fade out and slide left,
/// leaving a smear on the phone, while the bottom nav bar switched instantly.
///
/// Worth pinning because the thing that actually removes the *outgoing*
/// page's animation is the zero duration, not the overridden
/// buildTransitions -- someone restoring a duration "so the push looks nicer"
/// would bring the reported artefact straight back, and no other test would
/// notice.
void main() {
  testWidgets('an InstantPageRoute push leaves the previous page in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              InstantPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('pushed')),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    // One frame only: no pumpAndSettle, so anything still animating would
    // show up as the old page hanging around or the new one absent.
    await tester.pump();

    expect(find.text('pushed'), findsOneWidget);
    expect(find.text('go'), findsNothing);
  });

  test('both transition durations are zero', () {
    final route = InstantPageRoute<void>(builder: (_) => const SizedBox());
    expect(route.transitionDuration, Duration.zero);
    expect(
      route.reverseTransitionDuration,
      Duration.zero,
      reason: 'Going back must be instant too, or Home slides back in.',
    );
  });
}
