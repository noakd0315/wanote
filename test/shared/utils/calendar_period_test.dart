import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/utils/calendar_period.dart';

void main() {
  group('subtractCalendarMonths', () {
    test('subtracts within the same year', () {
      expect(
        subtractCalendarMonths(DateTime(2026, 8, 2), 3),
        DateTime(2026, 5, 2),
      );
    });

    test('subtracts across a year boundary', () {
      expect(
        subtractCalendarMonths(DateTime(2026, 8, 2), 12),
        DateTime(2025, 8, 2),
      );
    });

    test(
      'clamps day-of-month overflow (Mar 31 - 1 month -> Feb 28 in a non-leap year)',
      () {
        expect(
          subtractCalendarMonths(DateTime(2026, 3, 31), 1),
          DateTime(2026, 2, 28),
        );
      },
    );

    test('clamps day-of-month overflow into a leap February', () {
      expect(
        subtractCalendarMonths(DateTime(2024, 3, 31), 1),
        DateTime(2024, 2, 29),
      );
    });

    test('preserves time-of-day', () {
      expect(
        subtractCalendarMonths(DateTime(2026, 8, 2, 14, 23, 5), 1),
        DateTime(2026, 7, 2, 14, 23, 5),
      );
    });
  });

  group('trailingCalendarMonthsStart', () {
    test(
      'matches the PM-specified worked example (displayed date 2026-08-02)',
      () {
        final now = DateTime(2026, 8, 2, 14, 23);
        expect(trailingCalendarMonthsStart(now, 1), DateTime(2026, 7, 2));
        expect(trailingCalendarMonthsStart(now, 3), DateTime(2026, 5, 2));
        expect(trailingCalendarMonthsStart(now, 12), DateTime(2025, 8, 2));
      },
    );

    test(
      "truncates now's time-of-day so an exact-boundary midnight record isn't excluded",
      () {
        final now = DateTime(2026, 8, 2, 23, 59);
        final start = trailingCalendarMonthsStart(now, 3);
        expect(start, DateTime(2026, 5, 2));
        final boundaryRecord = DateTime(2026, 5, 2);
        expect(boundaryRecord.isBefore(start), isFalse);
      },
    );
  });
}
