import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/daily_record/domain/anomaly_detector.dart';
import 'package:wanote/features/daily_record/models/toilet_record.dart';
import 'package:wanote/shared/models/consultation_reference_record.dart';

void main() {
  const detector = AnomalyDetector();
  final now = DateTime(2026, 7, 15, 9, 0);

  ToiletRecord stool(
    String id,
    DateTime at, {
    StoolHardness hardness = StoolHardness.normal,
    StoolColor color = StoolColor.normal,
  }) => ToiletRecord(
    toiletId: id,
    petId: 'pet-1',
    recordedAt: at,
    type: ToiletType.stool,
    stoolCondition: StoolCondition(hardness: hardness, color: color),
  );

  group('blood-in-stool detection', () {
    test('a single blood-suspected record triggers the suggestion', () {
      final records = [
        stool(
          'a',
          DateTime(2026, 7, 14),
          hardness: StoolHardness.normal,
          color: StoolColor.bloodSuspected,
        ),
      ];
      final suggestions = detector.detect(records: records, now: now);
      expect(
        suggestions.map((s) => s.reason),
        contains(ConsultationSuggestionReason.bloodInStoolSuspected),
      );
    });

    test('no blood-suspected records means no suggestion', () {
      final records = [stool('a', DateTime(2026, 7, 14))];
      final suggestions = detector.detect(records: records, now: now);
      expect(
        suggestions.map((s) => s.reason),
        isNot(contains(ConsultationSuggestionReason.bloodInStoolSuspected)),
      );
    });

    test(
      'the suggestion carries a ConsultationReferenceRecord pointing at the triggering record',
      () {
        final records = [
          stool('a', DateTime(2026, 7, 14), color: StoolColor.bloodSuspected),
        ];
        final suggestions = detector.detect(records: records, now: now);
        final suggestion = suggestions.firstWhere(
          (s) => s.reason == ConsultationSuggestionReason.bloodInStoolSuspected,
        );
        expect(suggestion.reference.recordId, 'a');
        expect(
          suggestion.reference.recordType,
          ConsultationRecordType.toiletRecord,
        );
        expect(suggestion.reference.petId, 'pet-1');
      },
    );
  });

  group('prolonged diarrhea detection', () {
    test('fewer than the threshold consecutive days does not trigger', () {
      // Default threshold is 3; only 2 consecutive days here.
      final records = [
        stool('a', DateTime(2026, 7, 13), hardness: StoolHardness.diarrhea),
        stool('b', DateTime(2026, 7, 14), hardness: StoolHardness.diarrhea),
      ];
      final suggestions = detector.detect(records: records, now: now);
      expect(
        suggestions.map((s) => s.reason),
        isNot(contains(ConsultationSuggestionReason.prolongedDiarrhea)),
      );
    });

    test('exactly the threshold (3) consecutive days triggers', () {
      final records = [
        stool('a', DateTime(2026, 7, 12), hardness: StoolHardness.diarrhea),
        stool('b', DateTime(2026, 7, 13), hardness: StoolHardness.diarrhea),
        stool('c', DateTime(2026, 7, 14), hardness: StoolHardness.diarrhea),
      ];
      final suggestions = detector.detect(records: records, now: now);
      expect(
        suggestions.map((s) => s.reason),
        contains(ConsultationSuggestionReason.prolongedDiarrhea),
      );
    });

    test('more than the threshold consecutive days also triggers', () {
      final records = [
        stool('a', DateTime(2026, 7, 11), hardness: StoolHardness.diarrhea),
        stool('b', DateTime(2026, 7, 12), hardness: StoolHardness.diarrhea),
        stool('c', DateTime(2026, 7, 13), hardness: StoolHardness.diarrhea),
        stool('d', DateTime(2026, 7, 14), hardness: StoolHardness.diarrhea),
      ];
      final suggestions = detector.detect(records: records, now: now);
      expect(
        suggestions.map((s) => s.reason),
        contains(ConsultationSuggestionReason.prolongedDiarrhea),
      );
    });

    test(
      'non-consecutive diarrhea days do not trigger even if there are 3+ of them',
      () {
        final records = [
          stool('a', DateTime(2026, 7, 1), hardness: StoolHardness.diarrhea),
          stool('b', DateTime(2026, 7, 5), hardness: StoolHardness.diarrhea),
          stool('c', DateTime(2026, 7, 10), hardness: StoolHardness.diarrhea),
        ];
        final suggestions = detector.detect(records: records, now: now);
        expect(
          suggestions.map((s) => s.reason),
          isNot(contains(ConsultationSuggestionReason.prolongedDiarrhea)),
        );
      },
    );

    test('the threshold is configurable via the constructor', () {
      const strict = AnomalyDetector(diarrheaStreakThresholdDays: 5);
      final records = [
        stool('a', DateTime(2026, 7, 12), hardness: StoolHardness.diarrhea),
        stool('b', DateTime(2026, 7, 13), hardness: StoolHardness.diarrhea),
        stool('c', DateTime(2026, 7, 14), hardness: StoolHardness.diarrhea),
      ];
      // 3 consecutive days doesn't meet a threshold of 5.
      expect(
        strict.detect(records: records, now: now).map((s) => s.reason),
        isNot(contains(ConsultationSuggestionReason.prolongedDiarrhea)),
      );
    });
  });

  group('dedupe-per-day behavior', () {
    test('suppresses a reason already suggested earlier the same day', () {
      final records = [
        stool('a', DateTime(2026, 7, 14), color: StoolColor.bloodSuspected),
      ];
      final suggestions = detector.detect(
        records: records,
        now: now,
        lastSuggestedAt: {
          ConsultationSuggestionReason.bloodInStoolSuspected: DateTime(
            2026,
            7,
            15,
            6,
            0,
          ),
        },
      );
      expect(
        suggestions.map((s) => s.reason),
        isNot(contains(ConsultationSuggestionReason.bloodInStoolSuspected)),
      );
    });

    test('does not suppress once a new calendar day has started', () {
      final records = [
        stool('a', DateTime(2026, 7, 14), color: StoolColor.bloodSuspected),
      ];
      final suggestions = detector.detect(
        records: records,
        now: now,
        lastSuggestedAt: {
          ConsultationSuggestionReason.bloodInStoolSuspected: DateTime(
            2026,
            7,
            14,
            23,
            59,
          ),
        },
      );
      expect(
        suggestions.map((s) => s.reason),
        contains(ConsultationSuggestionReason.bloodInStoolSuspected),
      );
    });

    test('dedupe is independent per reason', () {
      final records = [
        stool('a', DateTime(2026, 7, 14), color: StoolColor.bloodSuspected),
        stool('b', DateTime(2026, 7, 12), hardness: StoolHardness.diarrhea),
        stool('c', DateTime(2026, 7, 13), hardness: StoolHardness.diarrhea),
        stool('d', DateTime(2026, 7, 14), hardness: StoolHardness.diarrhea),
      ];
      final suggestions = detector.detect(
        records: records,
        now: now,
        lastSuggestedAt: {
          ConsultationSuggestionReason.bloodInStoolSuspected: now,
        },
      );
      expect(
        suggestions.map((s) => s.reason),
        isNot(contains(ConsultationSuggestionReason.bloodInStoolSuspected)),
      );
      expect(
        suggestions.map((s) => s.reason),
        contains(ConsultationSuggestionReason.prolongedDiarrhea),
      );
    });
  });
}
