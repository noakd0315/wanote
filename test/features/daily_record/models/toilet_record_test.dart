import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/daily_record/models/toilet_record.dart';

void main() {
  group('UrineColor', () {
    test('wireName/fromWireName round-trip for every value', () {
      for (final color in UrineColor.values) {
        expect(UrineColor.fromWireName(color.wireName), color);
      }
    });

    test('fromWireName falls back to normal for an unknown value', () {
      expect(UrineColor.fromWireName('unknown'), UrineColor.normal);
    });
  });

  group('ToiletRecord urine_color field', () {
    test(
      'toMap/fromMap round-trip preserves urineColor for a urine record',
      () {
        final record = ToiletRecord(
          toiletId: 't1',
          petId: 'pet-1',
          recordedAt: DateTime(2026, 8, 2, 9, 30),
          type: ToiletType.urine,
          urineColor: UrineColor.dark,
        );
        final map = record.toMap();
        expect(map['urine_color'], 'dark');

        // fromMap reads back through a plain map, mirroring what a Firestore
        // document snapshot's .data() would hand back (Timestamp for dates).
        final roundTripped = ToiletRecord.fromMap({
          ...map,
          'recorded_at': Timestamp.fromDate(record.recordedAt),
        });
        expect(roundTripped.urineColor, UrineColor.dark);
        expect(roundTripped, record);
      },
    );

    test(
      'urineColor is null when absent from the map (e.g. a stool record)',
      () {
        final record = ToiletRecord(
          toiletId: 't2',
          petId: 'pet-1',
          recordedAt: DateTime(2026, 8, 2),
          type: ToiletType.stool,
          stoolCondition: const StoolCondition(
            hardness: StoolHardness.normal,
            color: StoolColor.normal,
          ),
        );
        final map = record.toMap();
        expect(map['urine_color'], isNull);

        final roundTripped = ToiletRecord.fromMap({
          ...map,
          'recorded_at': Timestamp.fromDate(record.recordedAt),
        });
        expect(roundTripped.urineColor, isNull);
      },
    );

    test('copyWith can set and clear urineColor independently', () {
      final record = ToiletRecord(
        toiletId: 't3',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 2),
        type: ToiletType.urine,
        urineColor: UrineColor.pale,
      );
      final updated = record.copyWith(urineColor: UrineColor.dark);
      expect(updated.urineColor, UrineColor.dark);

      final cleared = record.copyWith(clearUrineColor: true);
      expect(cleared.urineColor, isNull);
    });
  });
}
