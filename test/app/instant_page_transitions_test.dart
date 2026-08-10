import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/theme/app_theme.dart';

/// PM report: navigating between screens faded the outgoing one out and slid
/// it away, leaving a visible smear of the whole previous screen on a phone,
/// while the bottom nav bar switched instantly.
///
/// Worth pinning because the thing that removes the *outgoing* page's
/// animation is the zero duration, not the transition builder returning its
/// child -- someone restoring a duration "so pushes look nicer" would bring
/// the reported smear straight back, and no other test would notice.
void main() {
  Widget host(TargetPlatform platform) => MaterialApp(
    // The theme's platform is what selects the transition builder, so
    // setting it here is what actually exercises each entry.
    theme: buildWanoteTheme().copyWith(platform: platform),
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('pushed')),
          ),
        ),
        child: const Text('go'),
      ),
    ),
  );

  for (final platform in TargetPlatform.values) {
    testWidgets('a push is instant on $platform', (tester) async {
      await tester.pumpWidget(host(platform));
      await tester.tap(find.text('go'));
      // One frame only: anything still animating shows up as the old page
      // hanging around or the new one not yet there.
      await tester.pump();

      expect(find.text('pushed'), findsOneWidget);
      expect(
        find.text('go'),
        findsNothing,
        reason: 'The outgoing screen must not linger -- that is the smear.',
      );
    });
  }

  test('every platform gets a zero-duration transition', () {
    final theme = buildWanoteTheme().pageTransitionsTheme;
    for (final platform in TargetPlatform.values) {
      final builder = theme.builders[platform];
      expect(builder, isNotNull, reason: '$platform has no builder');
      expect(builder!.transitionDuration, Duration.zero, reason: '$platform');
      expect(
        builder.reverseTransitionDuration,
        Duration.zero,
        reason: 'Going back on $platform must be instant too.',
      );
    }
  });
}
