/// Calendar-month arithmetic shared by any feature that needs a "trailing N
/// calendar months, ending today" window (daily_record's weight trend chart,
/// ai's health report). Kept here rather than duplicated per feature so
/// their period boundaries can't silently drift apart -- which is exactly
/// what happened before this was extracted: the weight trend chart used
/// calendar-month subtraction (matching the PM's explicit worked example,
/// e.g. "表示日2026/8/2 → 3ヶ月：2026/5/2〜2026/8/2"), while the AI report
/// used a fixed 90-day `Duration`, which lands a few days off from a true
/// "3 months ago" since calendar months vary from 28-31 days.
library;

/// Subtracts [months] calendar months from [date] -- equivalent to C#'s
/// `date.AddMonths(-months)` -- clamping the day of month down when the
/// target month is shorter (e.g. Mar 31 - 1 month = Feb 28/29, not an
/// overflowed Mar 3).
DateTime subtractCalendarMonths(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) - months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final daysInTargetMonth = DateTime(year, month + 1, 0).day;
  final day = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
  return DateTime(
    year,
    month,
    day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// The start of a trailing [months]-calendar-month window ending on [now]'s
/// calendar date. [now]'s time-of-day is truncated away before subtracting,
/// so a record stored at midnight on the exact boundary date is still
/// included -- a record dated exactly "N months ago today" would otherwise
/// be excluded whenever `now`'s wall-clock time is later than midnight.
DateTime trailingCalendarMonthsStart(DateTime now, int months) {
  final today = DateTime(now.year, now.month, now.day);
  return subtractCalendarMonths(today, months);
}
