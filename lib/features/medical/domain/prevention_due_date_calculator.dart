import 'models/prevention_program.dart';

/// Pure, framework-free calculation of `prevention_records.next_due_date`
/// from a program's schedule and the most recent `administered_at` (spec
/// 5.3). No Firestore/DateTime.now() dependency, so this is exhaustively
/// unit-testable.
///
/// Design choices (documented per task instructions):
/// - `monthly` advances by **+1 calendar month** from `administered_at`
///   (not a flat +30 days). Heartworm/flea-tick products are almost always
///   dosed "once a month", and calendar-month arithmetic keeps the due date
///   anchored to the same day-of-month across the year instead of slowly
///   drifting earlier (30-day steps lose ~5 days/year versus 12 calendar
///   months). Day-of-month overflow (e.g. Jan 31 -> Feb) clamps to the last
///   valid day of the target month.
/// - `annual` advances by **+1 calendar year**, with the same Feb 29 -> Feb
///   28 clamping in non-leap years.
/// - `custom` advances by exactly `interval_days` (required by the model
///   when `schedule_type == custom`).
/// - `single` never auto-calculates: the spec only auto-computes for
///   monthly/annual ("monthly/annualの場合は interval_days から自動計算");
///   single-dose items (typical for vaccine) rely entirely on whatever the
///   user manually entered on the record, so we just echo it back.
class PreventionDueDateCalculator {
  const PreventionDueDateCalculator();

  /// Returns the next due date, or `null` if none can be determined (e.g. a
  /// `single` schedule with no manual date entered).
  DateTime? calculateNextDueDate({
    required ScheduleType scheduleType,
    required DateTime administeredAt,
    int? intervalDays,
    DateTime? manualNextDueDate,
  }) {
    switch (scheduleType) {
      case ScheduleType.single:
        return manualNextDueDate;
      case ScheduleType.monthly:
        return _addMonths(administeredAt, 1);
      case ScheduleType.annual:
        return _addMonths(administeredAt, 12);
      case ScheduleType.custom:
        if (intervalDays == null) {
          throw ArgumentError(
            'intervalDays is required to calculate a custom-schedule due date',
          );
        }
        return administeredAt.add(Duration(days: intervalDays));
    }
  }

  /// Adds [months] calendar months to [date], clamping the day-of-month to
  /// the last valid day of the resulting month (e.g. Jan 31 + 1 month ->
  /// Feb 28/29, never Mar 3).
  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = (date.year * 12 + (date.month - 1)) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : date.day;
    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
    );
  }
}
