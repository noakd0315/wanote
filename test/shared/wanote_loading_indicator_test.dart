import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/widgets/wanote_loading_indicator.dart';

/// A load that finishes quickly must not flash the indicator on and off as
/// a screen opens -- that reads as a glitch rather than as loading (PM
/// report, 2026-08-18).
void main() {
  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('draws nothing during its delay', (tester) async {
    await tester.pumpWidget(wrap(const WanoteLoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Image), findsNothing);
    expect(find.text('loading...'), findsNothing);
  });

  testWidgets('appears once the delay has passed', (tester) async {
    await tester.pumpWidget(wrap(const WanoteLoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('loading...'), findsOneWidget);
    // Let the repeating pulse stop being pumped.
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('shows immediately when the delay is waived', (tester) async {
    await tester.pumpWidget(
      wrap(const WanoteLoadingIndicator(delay: Duration.zero)),
    );
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('disposing during the delay does not throw', (tester) async {
    // The controller used to be a lazy field, so a widget that never built
    // its animation first touched it in dispose() -- constructing a ticker
    // on a deactivated element, which asserts.
    await tester.pumpWidget(wrap(const WanoteLoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(wrap(const SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
