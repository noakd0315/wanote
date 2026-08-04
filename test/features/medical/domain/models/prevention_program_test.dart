import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/domain/models/prevention_program.dart';

void main() {
  group('PreventionType', () {
    test('wireName/fromWireName round-trip for every value', () {
      for (final type in PreventionType.values) {
        expect(PreventionType.fromWireName(type.wireName), type);
      }
    });

    test(
      'fromWireName maps legacy heartworm/flea_tick values to medication',
      () {
        // Pre-merge Firestore docs stored these two separate wire values
        // (PM report: flea+tick+heartworm combo products exist as a single
        // medication, so the split was merged into one type). Existing
        // docs must keep resolving correctly rather than silently falling
        // back to vaccine.
        expect(
          PreventionType.fromWireName('heartworm'),
          PreventionType.medication,
        );
        expect(
          PreventionType.fromWireName('flea_tick'),
          PreventionType.medication,
        );
      },
    );

    test('fromWireName falls back to vaccine for an unknown value', () {
      expect(PreventionType.fromWireName('unknown'), PreventionType.vaccine);
    });
  });
}
