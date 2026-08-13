import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/theme/app_theme.dart';

/// Guards a decision that is easy to undo by accident.
///
/// A global `pageTransitionsTheme` was briefly set to make every screen
/// change instant, after screens were seen fading out and leaving a smear
/// behind on iOS Safari. That override silently costs two platform gestures:
/// Android's predictive back preview and iOS's interactive edge-swipe-back,
/// both of which live in the default builders and neither of which any other
/// test exercises. The smear was a web observation and the app ships
/// natively, so the override was reverted pending a check on a device.
///
/// If it does need to come back, it has to come back knowing what it costs --
/// which is what this test is here to say.
void main() {
  test('Android keeps the predictive back transition', () {
    final builder = buildWanoteTheme()
        .pageTransitionsTheme
        .builders[TargetPlatform.android];

    expect(
      builder,
      isA<PredictiveBackPageTransitionsBuilder>(),
      reason: 'Overriding this removes the back-gesture preview.',
    );
  });

  test('iOS keeps the interactive swipe-back transition', () {
    final builder =
        buildWanoteTheme().pageTransitionsTheme.builders[TargetPlatform.iOS];

    expect(
      builder,
      isA<CupertinoPageTransitionsBuilder>(),
      reason: 'Overriding this removes the edge-swipe-to-go-back gesture.',
    );
  });

  testWidgets('the swipe-back gesture actually pops on iOS', (tester) async {
    // The type check above only says which builder is configured; this is the
    // behaviour that would actually be lost.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWanoteTheme().copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('pushed')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);

    // Drag in from the left edge, the way the platform gesture works.
    await tester.dragFrom(const Offset(2, 300), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('pushed'), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
