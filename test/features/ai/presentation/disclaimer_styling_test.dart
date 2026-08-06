import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/ai/presentation/widgets/disclaimer_banner.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

/// PM request: the safety notices must be red, not the muted grey they were
/// rendered in. Asserted against colorScheme.error rather than a literal
/// Color so the notices keep following the theme (including dark mode)
/// instead of silently drifting to an unreadable hard-coded red.
///
/// Worth pinning: a colour is easy to revert by accident during unrelated
/// styling work, and nothing else would fail if the "本機能は医療診断では
/// ありません" notice quietly went back to grey.

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ja'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('the AI disclaimer text and icon are rendered in the error colour', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DisclaimerBanner()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(DisclaimerBanner));
    final expected = Theme.of(context).colorScheme.error;

    final text = tester.widget<Text>(find.byType(Text));
    expect(
      text.style?.color,
      expected,
      reason: 'The 医療診断ではない notice must stand out as a caution.',
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, expected, reason: 'The icon must match the text.');
  });

  testWidgets('the disclaimer follows the theme in dark mode too', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        theme: ThemeData.dark(),
        home: const Scaffold(body: DisclaimerBanner()),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(DisclaimerBanner));
    final text = tester.widget<Text>(find.byType(Text));
    expect(
      text.style?.color,
      Theme.of(context).colorScheme.error,
      reason: 'A hard-coded red would be unreadable on a dark surface.',
    );
  });
}
