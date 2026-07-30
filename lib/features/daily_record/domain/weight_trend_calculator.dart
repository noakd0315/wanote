import '../models/weight_record.dart';

/// Chart period toggle from spec 3.2 ("折れ線グラフ表示（期間切り替え：1ヶ月
/// ／3ヶ月／1年）").
enum WeightTrendPeriod { oneMonth, threeMonths, oneYear }

/// Result of [WeightTrendCalculator.calculate]: the series to plot for the
/// selected period, plus the two deltas spec 3.4 asks for as the MVP
/// replacement for a breed/age weight-range comparison ("前回比」「1ヶ月前比」
/// の増減表示に留めるのが現実的").
class WeightTrendResult {
  const WeightTrendResult({
    required this.series,
    required this.deltaVsPrevious,
    required this.deltaVsOneMonthAgo,
  });

  /// Records within the selected period, sorted ascending by [WeightRecord.measuredAt].
  final List<WeightRecord> series;

  /// latest.weightKg - secondLatest.weightKg, using the two most recent
  /// records overall (independent of the period filter — the delta badge is
  /// meant to always reflect "vs the previous entry", not "vs the previous
  /// entry visible in the current chart window"). Null if fewer than 2
  /// records exist in total.
  final double? deltaVsPrevious;

  /// latest.weightKg minus the weight of the most recent record at or before
  /// (latest.measuredAt - 1 month). Null if no such record exists.
  final double? deltaVsOneMonthAgo;

  @override
  String toString() =>
      'WeightTrendResult(series: ${series.length} pts, deltaVsPrevious: $deltaVsPrevious, deltaVsOneMonthAgo: $deltaVsOneMonthAgo)';
}

/// Pure, framework-free calculation for the weight chart screen (spec
/// section 3). Deliberately has no Firestore/Flutter dependency so it can be
/// unit tested with plain `List<WeightRecord>` fixtures.
class WeightTrendCalculator {
  const WeightTrendCalculator();

  WeightTrendResult calculate({
    required List<WeightRecord> records,
    required DateTime now,
    required WeightTrendPeriod period,
  }) {
    final sorted = [...records]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final cutoff = _periodStart(now, period);
    final series = sorted
        .where((r) => !r.measuredAt.isBefore(cutoff) && !r.measuredAt.isAfter(now))
        .toList();

    double? deltaVsPrevious;
    double? deltaVsOneMonthAgo;

    if (sorted.isNotEmpty) {
      final latest = sorted.last;

      if (sorted.length >= 2) {
        final previous = sorted[sorted.length - 2];
        deltaVsPrevious = latest.weightKg - previous.weightKg;
      }

      final oneMonthAgoTarget = _subtractMonths(latest.measuredAt, 1);
      WeightRecord? closest;
      for (final r in sorted) {
        if (!r.measuredAt.isAfter(oneMonthAgoTarget)) {
          // Keep the latest one at or before the target (i.e. the closest
          // from below), since sorted is ascending.
          closest = r;
        } else {
          break;
        }
      }
      if (closest != null && !identical(closest, latest)) {
        deltaVsOneMonthAgo = latest.weightKg - closest.weightKg;
      }
    }

    return WeightTrendResult(
      series: series,
      deltaVsPrevious: deltaVsPrevious,
      deltaVsOneMonthAgo: deltaVsOneMonthAgo,
    );
  }

  DateTime _periodStart(DateTime now, WeightTrendPeriod period) {
    switch (period) {
      case WeightTrendPeriod.oneMonth:
        return _subtractMonths(now, 1);
      case WeightTrendPeriod.threeMonths:
        return _subtractMonths(now, 3);
      case WeightTrendPeriod.oneYear:
        return _subtractMonths(now, 12);
    }
  }

  /// Subtracts [months] calendar months from [date], clamping the day of
  /// month down when the target month is shorter (e.g. Mar 31 - 1 month =
  /// Feb 28/29, not an overflowed Mar 3).
  DateTime _subtractMonths(DateTime date, int months) {
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
}
