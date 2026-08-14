import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/utils/formatting.dart';

/// Dates and weights follow the language, and weights are still stored in
/// kilograms whatever the reader sees.
///
/// That second half is the one worth a test. A weight typed in pounds and
/// stored as pounds would corrupt the history the moment someone switched
/// language, and nothing about the app would look wrong until much later.
void main() {
  Future<BuildContext> pumpWithLocale(WidgetTester tester, Locale locale) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('weights read in the reader\'s unit', (tester) async {
    final ja = await pumpWithLocale(tester, const Locale('ja'));
    expect(formatWeight(ja, 12.0), '12.0 kg');

    final en = await pumpWithLocale(tester, const Locale('en'));
    expect(formatWeight(en, 12.0), '26.5 lb');
  });

  testWidgets('a weight typed in pounds is stored in kilograms', (
    tester,
  ) async {
    final en = await pumpWithLocale(tester, const Locale('en'));
    final kg = parseWeightToKilograms(en, '26.5');
    expect(kg, isNotNull);
    expect(kg!, closeTo(12.0, 0.05));

    final ja = await pumpWithLocale(tester, const Locale('ja'));
    expect(parseWeightToKilograms(ja, '12'), 12.0);
  });

  testWidgets('the field is prefilled in the unit it asks for', (tester) async {
    final en = await pumpWithLocale(tester, const Locale('en'));
    expect(weightInputUnit(en), 'lb');
    expect(weightInputText(en, 12.0), '26.5');

    final ja = await pumpWithLocale(tester, const Locale('ja'));
    expect(weightInputUnit(ja), 'kg');
    // Trailing zeros are dropped: the owner is about to edit this.
    expect(weightInputText(ja, 12.0), '12');
  });

  testWidgets('a round trip through the field does not drift', (tester) async {
    final en = await pumpWithLocale(tester, const Locale('en'));
    final shown = weightInputText(en, 12.3);
    expect(parseWeightToKilograms(en, shown)!, closeTo(12.3, 0.05));
  });

  testWidgets('nothing is stored for blank or nonsense input', (tester) async {
    final ja = await pumpWithLocale(tester, const Locale('ja'));
    expect(parseWeightToKilograms(ja, ''), isNull);
    expect(parseWeightToKilograms(ja, 'abc'), isNull);
    expect(parseWeightToKilograms(ja, '0'), isNull);
    expect(parseWeightToKilograms(ja, '-3'), isNull);
  });

  testWidgets('dates read month-first in English, year-first in Japanese', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 14, 17, 5);

    final ja = await pumpWithLocale(tester, const Locale('ja'));
    expect(formatDate(ja, date), '2026/8/14');

    final en = await pumpWithLocale(tester, const Locale('en'));
    expect(formatDate(en, date), '8/14/2026');
  });

  testWidgets('food quantities follow the same unit choice', (tester) async {
    final ja = await pumpWithLocale(tester, const Locale('ja'));
    expect(formatFoodQuantity(ja, 200), '200 g');

    final en = await pumpWithLocale(tester, const Locale('en'));
    expect(formatFoodQuantity(en, 200), '7.1 oz');
  });
}
