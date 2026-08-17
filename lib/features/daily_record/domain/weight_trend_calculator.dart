import '../../../shared/utils/calendar_period.dart';
import '../models/weight_record.dart';

/// Chart period toggle. Spec 3.2 asked for 1ヶ月／3ヶ月／1年, but the PM
/// widened the shortest window: unlike people, dogs are not weighed daily, so
/// a one-month view was usually two or three points and read as noise
/// ("人間と違い毎日図らないと思うので、３か月、6カ月、１年としてください").
enum WeightTrendPeriod { threeMonths, sixMonths, oneYear, all }

/// Result of [WeightTrendCalculator.calculate]: the series to plot for the
/// selected period, plus the two deltas spec 3.4 asks for as the MVP
/// replacement for a breed/age weight-range comparison ("前回比」「1ヶ月前比」
/// の増減表示に留めるのが現実的").
class WeightTrendResult {
  const WeightTrendResult({
    required this.series,
    required this.deltaVsPrevious,
    required this.deltaVsOneMonthAgo,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Records within the selected period, sorted ascending by [WeightRecord.measuredAt].
  final List<WeightRecord> series;

  /// The exact start/end of the selected window -- `periodEnd` is always
  /// the `now` passed to [WeightTrendCalculator.calculate] and `periodStart`
  /// is `periodEnd` minus the period's calendar months (e.g. for `now` =
  /// 2026-08-02 and [WeightTrendPeriod.threeMonths], periodStart is 2026-05-02).
  /// Exposed so the screen can display the range explicitly rather than the
  /// user having to infer it from which points happen to be plotted.
  final DateTime periodStart;
  final DateTime periodEnd;

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
    final sorted = [...records]
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    // "All" starts at the first record rather than at some arbitrary early
    // date, so the displayed range reads as the pet's actual history. With
    // no records at all there is nothing to bound, so it collapses to `now`
    // and the empty series speaks for itself.
    final cutoff = period == WeightTrendPeriod.all
        ? (sorted.isEmpty ? now : sorted.first.measuredAt)
        : _periodStart(now, period);
    final series = sorted
        .where(
          (r) => !r.measuredAt.isBefore(cutoff) && !r.measuredAt.isAfter(now),
        )
        .toList();

    double? deltaVsPrevious;
    double? deltaVsOneMonthAgo;

    if (sorted.isNotEmpty) {
      final latest = sorted.last;

      if (sorted.length >= 2) {
        final previous = sorted[sorted.length - 2];
        deltaVsPrevious = latest.weightKg - previous.weightKg;
      }

      final oneMonthAgoTarget = subtractCalendarMonths(latest.measuredAt, 1);
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
      periodStart: cutoff,
      periodEnd: now,
    );
  }

  /// See [trailingCalendarMonthsStart] (lib/shared/utils/calendar_period.dart)
  /// for why `now`'s time-of-day is truncated away before subtracting --
  /// this is the fix for the boundary bug where a record dated exactly "N
  /// months ago today" was silently excluded, even though spec's own
  /// example ("1年：2025/8/2〜2026/8/2") is explicit that the boundary date
  /// itself is included. Shared with the AI health report's period
  /// calculation so the two features can't drift apart on what "3 months"
  /// means.
  DateTime _periodStart(DateTime now, WeightTrendPeriod period) {
    final months = switch (period) {
      WeightTrendPeriod.threeMonths => 3,
      WeightTrendPeriod.sixMonths => 6,
      WeightTrendPeriod.oneYear => 12,
      // Handled by the caller, which needs the records to answer it.
      WeightTrendPeriod.all => throw ArgumentError(
        'WeightTrendPeriod.all has no fixed month count',
      ),
    };
    return trailingCalendarMonthsStart(now, months);
  }
}
