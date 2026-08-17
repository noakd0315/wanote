import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/utils/formatting.dart';

/// The measurements are stored in centimetres and shown in whichever unit
/// the reader's language implies -- the same split weight already has. The
/// risk being tested is the one that matters: a number typed as inches
/// getting stored as if it were centimetres.
void main() {
  Future<BuildContext> contextIn(WidgetTester tester, Locale locale) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('lengths read in the reader\'s unit', (tester) async {
    final ja = await contextIn(tester, const Locale('ja'));
    expect(formatLength(ja, 40), '40.0 cm');
    expect(lengthInputUnit(ja), 'cm');

    final en = await contextIn(tester, const Locale('en'));
    expect(formatLength(en, 2.54), '1.0 in');
    expect(lengthInputUnit(en), 'in');
  });

  testWidgets('a measurement typed in inches is stored in centimetres', (
    tester,
  ) async {
    final en = await contextIn(tester, const Locale('en'));
    expect(parseLengthToCentimetres(en, '10'), closeTo(25.4, 0.001));

    final ja = await contextIn(tester, const Locale('ja'));
    expect(parseLengthToCentimetres(ja, '10'), 10);
  });

  testWidgets('a round trip through the field does not drift', (tester) async {
    final en = await contextIn(tester, const Locale('en'));
    final stored = parseLengthToCentimetres(en, '12.5');
    expect(lengthInputText(en, stored), '12.5');
  });

  testWidgets('nothing is stored for blank or nonsense input', (tester) async {
    final ja = await contextIn(tester, const Locale('ja'));
    expect(parseLengthToCentimetres(ja, ''), isNull);
    expect(parseLengthToCentimetres(ja, 'abc'), isNull);
    // Zero and negatives are not measurements.
    expect(parseLengthToCentimetres(ja, '0'), isNull);
    expect(parseLengthToCentimetres(ja, '-5'), isNull);
    expect(lengthInputText(ja, null), '');
  });
}
