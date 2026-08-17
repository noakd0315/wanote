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

  group('ToiletRecord location field', () {
    test('toMap/fromMap round-trip preserves location for either type', () {
      final record = ToiletRecord(
        toiletId: 't4',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 2, 9, 30),
        type: ToiletType.stool,
        stoolCondition: const StoolCondition(
          hardness: StoolHardness.normal,
          color: StoolColor.normal,
        ),
        location: '庭',
      );
      final map = record.toMap();
      expect(map['location'], '庭');

      final roundTripped = ToiletRecord.fromMap({
        ...map,
        'recorded_at': Timestamp.fromDate(record.recordedAt),
      });
      expect(roundTripped.location, '庭');
      expect(roundTripped, record);
    });

    test('location is null when absent from the map', () {
      final record = ToiletRecord(
        toiletId: 't5',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 2),
        type: ToiletType.urine,
        urineColor: UrineColor.normal,
      );
      final map = record.toMap();
      expect(map['location'], isNull);

      final roundTripped = ToiletRecord.fromMap({
        ...map,
        'recorded_at': Timestamp.fromDate(record.recordedAt),
      });
      expect(roundTripped.location, isNull);
    });

    test('copyWith can set and clear location independently', () {
      final record = ToiletRecord(
        toiletId: 't6',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 2),
        type: ToiletType.urine,
        urineColor: UrineColor.normal,
        location: '散歩中',
      );
      final updated = record.copyWith(location: '庭');
      expect(updated.location, '庭');

      final cleared = record.copyWith(clearLocation: true);
      expect(cleared.location, isNull);
    });
  });

  // PM request: "排尿に量（少ない・普通・多い）を選べるようにしたい".
  group('urine volume', () {
    test('survives a toMap/fromMap round trip', () {
      final record = ToiletRecord(
        toiletId: 't-1',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 17, 7, 30),
        type: ToiletType.urine,
        urineColor: UrineColor.dark,
        urineVolume: UrineVolume.large,
      );
      final restored = ToiletRecord.fromMap(record.toMap());
      expect(restored.urineVolume, UrineVolume.large);
      expect(restored.urineColor, UrineColor.dark);
    });

    test('a record saved before the field existed reads back as null', () {
      final record = ToiletRecord(
        toiletId: 't-2',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 1),
        type: ToiletType.urine,
        urineColor: UrineColor.normal,
      );
      final map = record.toMap()..remove('urine_volume');
      expect(ToiletRecord.fromMap(map).urineVolume, isNull);
    });

    test('an unrecognised stored value falls back to normal', () {
      final record = ToiletRecord(
        toiletId: 't-3',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 1),
        type: ToiletType.urine,
        urineVolume: UrineVolume.small,
      );
      final map = record.toMap()..['urine_volume'] = 'enormous';
      expect(ToiletRecord.fromMap(map).urineVolume, UrineVolume.normal);
    });
  });
}
