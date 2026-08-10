import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/app/home_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

/// PM request: the Home shortcuts must all be the same size within a
/// language, and must stay readable over any background photo.
///
/// Equal size is a property of the layout (equal-width Expanded tiles inside
/// an IntrinsicHeight), not of the labels -- and it is exactly what breaks if
/// someone goes back to self-sizing chips or a Wrap, which is invisible in a
/// diff and only shows up on the one screen nobody unit tests.

Widget _host(Locale locale, Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  home: child,
);

void main() {
  for (final locale in const [Locale('ja'), Locale('en')]) {
    testWidgets('every shortcut is the same size in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          locale,
          Scaffold(
            body: HomeShortcutRow(
              onWeight: () {},
              onToilet: () {},
              onCertificates: () {},
              onConsultation: () {},
              onFoodPortion: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tiles = find.byType(InkWell);
      expect(tiles, findsNWidgets(5));

      final sizes = <Size>[
        for (var i = 0; i < 5; i++) tester.getSize(tiles.at(i)),
      ];
      for (final size in sizes) {
        expect(
          size,
          sizes.first,
          reason:
              'Shortcuts differ in size in ${locale.languageCode}: $sizes. '
              'Self-sizing chips size to their label, which is the bug.',
        );
      }
    });
  }
}
