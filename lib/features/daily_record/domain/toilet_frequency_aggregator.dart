import '../models/toilet_record.dart';

/// Pure, framework-free daily-count aggregation for the toilet frequency bar
/// chart (spec 4.2: "頻度グラフ（日別回数の推移）"). No Firestore/Flutter
/// dependency, so it's unit-testable with plain `List<ToiletRecord>` fixtures.
class ToiletFrequencyAggregator {
  const ToiletFrequencyAggregator();

  /// Buckets [records] by calendar day (year/month/day, time-of-day
  /// discarded) and counts how many fall on each day. If [type] is provided,
  /// only records of that [ToiletType] are counted (e.g. to chart urine and
  /// stool separately); otherwise all records count.
  ///
  /// The returned map's keys are normalized `DateTime`s (midnight, local)
  /// and are not guaranteed to be in any particular order — sort the entries
  /// yourself if the chart needs a specific axis order. Days with zero
  /// records are simply absent from the map (not included as zero entries).
  Map<DateTime, int> aggregateDailyCounts(
    List<ToiletRecord> records, {
    ToiletType? type,
  }) {
    final result = <DateTime, int>{};
    for (final record in records) {
      if (type != null && record.type != type) continue;
      final day = _dateOnly(record.recordedAt);
      result[day] = (result[day] ?? 0) + 1;
    }
    return result;
  }

  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}
