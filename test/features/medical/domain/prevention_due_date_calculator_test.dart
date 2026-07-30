import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/domain/models/prevention_program.dart';
import 'package:wanote/features/medical/domain/prevention_due_date_calculator.dart';

void main() {
  final calculator = PreventionDueDateCalculator();

  group('PreventionDueDateCalculator', () {
    test('single schedule returns the manual date unchanged', () {
      final administeredAt = DateTime(2026, 1, 10);
      final manual = DateTime(2027, 1, 10);

      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.single,
        administeredAt: administeredAt,
        manualNextDueDate: manual,
      );

      expect(result, manual);
    });

    test('single schedule with no manual date returns null (no auto-calc)', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.single,
        administeredAt: DateTime(2026, 1, 10),
      );

      expect(result, isNull);
    });

    test('monthly schedule adds one calendar month', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.monthly,
        administeredAt: DateTime(2026, 3, 15),
      );

      expect(result, DateTime(2026, 4, 15));
    });

    test('monthly schedule clamps day-of-month overflow (Jan 31 -> Feb 28)', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.monthly,
        administeredAt: DateTime(2026, 1, 31),
      );

      // 2026 is not a leap year.
      expect(result, DateTime(2026, 2, 28));
    });

    test('monthly schedule handles year rollover (Dec -> Jan)', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.monthly,
        administeredAt: DateTime(2026, 12, 5),
      );

      expect(result, DateTime(2027, 1, 5));
    });

    test('annual schedule adds one calendar year', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.annual,
        administeredAt: DateTime(2026, 6, 1),
      );

      expect(result, DateTime(2027, 6, 1));
    });

    test('annual schedule clamps Feb 29 in a non-leap target year', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.annual,
        administeredAt: DateTime(2028, 2, 29), // 2028 is a leap year
      );

      // 2029 is not a leap year, so Feb 29 clamps to Feb 28.
      expect(result, DateTime(2029, 2, 28));
    });

    test('custom schedule adds exactly intervalDays', () {
      final result = calculator.calculateNextDueDate(
        scheduleType: ScheduleType.custom,
        administeredAt: DateTime(2026, 1, 1),
        intervalDays: 45,
      );

      expect(result, DateTime(2026, 1, 1).add(const Duration(days: 45)));
    });

    test('custom schedule throws without intervalDays', () {
      expect(
        () => calculator.calculateNextDueDate(
          scheduleType: ScheduleType.custom,
          administeredAt: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
