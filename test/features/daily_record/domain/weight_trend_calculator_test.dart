import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/daily_record/domain/weight_trend_calculator.dart';
import 'package:wanote/features/daily_record/models/weight_record.dart';

void main() {
  const calculator = WeightTrendCalculator();
  final now = DateTime(2026, 7, 15);

  WeightRecord record(String id, DateTime date, double kg) =>
      WeightRecord(weightId: id, petId: 'pet-1', measuredAt: date, weightKg: kg);

  group('period filtering', () {
    final r8 = record('r8', DateTime(2025, 6, 1), 7.5); // before 1yr cutoff
    final r7 = record('r7', DateTime(2025, 8, 1), 8.0); // within 1yr only
    final r6 = record('r6', DateTime(2026, 4, 10), 8.8); // before 3mo cutoff, within 1yr
    final r5 = record('r5', DateTime(2026, 5, 1), 9.0); // within 3mo
    final r4 = record('r4', DateTime(2026, 6, 10), 9.3); // before 1mo cutoff, within 3mo
    final r3 = record('r3', DateTime(2026, 6, 16), 9.5); // within 1mo
    final r2 = record('r2', DateTime(2026, 7, 1), 9.8); // within 1mo
    final r1 = record('r1', DateTime(2026, 7, 15), 10.0); // == now

    final all = [r8, r7, r6, r5, r4, r3, r2, r1];

    test('1 month keeps only records on/after now-1mo', () {
      final result = calculator.calculate(records: all, now: now, period: WeightTrendPeriod.oneMonth);
      expect(result.series.map((r) => r.weightId), ['r3', 'r2', 'r1']);
    });

    test('3 months keeps only records on/after now-3mo', () {
      final result = calculator.calculate(records: all, now: now, period: WeightTrendPeriod.threeMonths);
      expect(result.series.map((r) => r.weightId), ['r5', 'r4', 'r3', 'r2', 'r1']);
    });

    test('1 year keeps only records on/after now-1yr', () {
      final result = calculator.calculate(records: all, now: now, period: WeightTrendPeriod.oneYear);
      expect(result.series.map((r) => r.weightId), ['r7', 'r6', 'r5', 'r4', 'r3', 'r2', 'r1']);
    });

    test('series is sorted ascending by measuredAt regardless of input order', () {
      final shuffled = [r1, r5, r3, r2, r4];
      final result = calculator.calculate(records: shuffled, now: now, period: WeightTrendPeriod.threeMonths);
      expect(result.series.map((r) => r.weightId), ['r5', 'r4', 'r3', 'r2', 'r1']);
    });

    test('a record exactly at the cutoff boundary is included (inclusive lower bound)', () {
      final boundary = record('boundary', DateTime(2026, 6, 15), 9.6); // exactly now - 1 month
      final result = calculator.calculate(records: [...all, boundary], now: now, period: WeightTrendPeriod.oneMonth);
      expect(result.series.map((r) => r.weightId), contains('boundary'));
    });
  });

  group('deltas', () {
    test('deltaVsPrevious compares the two most recent records overall (ignoring period filter)', () {
      final records = [
        record('a', DateTime(2026, 5, 1), 9.0),
        record('b', DateTime(2026, 7, 1), 9.8),
        record('c', DateTime(2026, 7, 15), 10.0),
      ];
      final result = calculator.calculate(records: records, now: now, period: WeightTrendPeriod.oneMonth);
      expect(result.deltaVsPrevious, closeTo(0.2, 1e-9));
    });

    test('deltaVsOneMonthAgo compares latest against the closest record at/before latest-1mo', () {
      final records = [
        record('old', DateTime(2026, 6, 10), 9.3), // closest at/before 2026-06-15
        record('mid', DateTime(2026, 6, 16), 9.5), // after the 1-month-ago target, must be ignored
        record('latest', DateTime(2026, 7, 15), 10.0),
      ];
      final result = calculator.calculate(records: records, now: now, period: WeightTrendPeriod.oneYear);
      expect(result.deltaVsOneMonthAgo, closeTo(0.7, 1e-9));
    });

    test('deltaVsOneMonthAgo is null when no record exists at/before the target date', () {
      final records = [
        record('recent1', DateTime(2026, 7, 10), 9.9),
        record('recent2', DateTime(2026, 7, 15), 10.0),
      ];
      final result = calculator.calculate(records: records, now: now, period: WeightTrendPeriod.oneYear);
      expect(result.deltaVsOneMonthAgo, isNull);
    });
  });

  group('edge cases', () {
    test('empty input yields empty series and null deltas', () {
      final result = calculator.calculate(records: const [], now: now, period: WeightTrendPeriod.oneMonth);
      expect(result.series, isEmpty);
      expect(result.deltaVsPrevious, isNull);
      expect(result.deltaVsOneMonthAgo, isNull);
    });

    test('a single record yields a 1-item series and null deltas', () {
      final only = record('only', DateTime(2026, 7, 10), 10.0);
      final result = calculator.calculate(records: [only], now: now, period: WeightTrendPeriod.oneMonth);
      expect(result.series, [only]);
      expect(result.deltaVsPrevious, isNull);
      expect(result.deltaVsOneMonthAgo, isNull);
    });
  });

  group('periodStart/periodEnd (PM-specified example: displayed date 2026-08-02)', () {
    final displayDate = DateTime(2026, 8, 2);

    test('1 month -> 2026-07-02 to 2026-08-02', () {
      final result = calculator.calculate(
        records: const [],
        now: displayDate,
        period: WeightTrendPeriod.oneMonth,
      );
      expect(result.periodStart, DateTime(2026, 7, 2));
      expect(result.periodEnd, DateTime(2026, 8, 2));
    });

    test('3 months -> 2026-05-02 to 2026-08-02', () {
      final result = calculator.calculate(
        records: const [],
        now: displayDate,
        period: WeightTrendPeriod.threeMonths,
      );
      expect(result.periodStart, DateTime(2026, 5, 2));
      expect(result.periodEnd, DateTime(2026, 8, 2));
    });

    test('1 year -> 2025-08-02 to 2026-08-02', () {
      final result = calculator.calculate(
        records: const [],
        now: displayDate,
        period: WeightTrendPeriod.oneYear,
      );
      expect(result.periodStart, DateTime(2025, 8, 2));
      expect(result.periodEnd, DateTime(2026, 8, 2));
    });
  });
}
