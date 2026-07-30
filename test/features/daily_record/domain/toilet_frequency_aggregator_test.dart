import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/daily_record/domain/toilet_frequency_aggregator.dart';
import 'package:wanote/features/daily_record/models/toilet_record.dart';

void main() {
  const aggregator = ToiletFrequencyAggregator();

  ToiletRecord urine(String id, DateTime at) =>
      ToiletRecord(toiletId: id, petId: 'pet-1', recordedAt: at, type: ToiletType.urine);

  ToiletRecord stool(String id, DateTime at, {StoolHardness hardness = StoolHardness.normal}) => ToiletRecord(
    toiletId: id,
    petId: 'pet-1',
    recordedAt: at,
    type: ToiletType.stool,
    stoolCondition: StoolCondition(hardness: hardness, color: StoolColor.normal),
  );

  test('empty input yields an empty map', () {
    expect(aggregator.aggregateDailyCounts(const []), isEmpty);
  });

  test('buckets multiple records on the same day into one count, ignoring time-of-day', () {
    final records = [
      urine('a', DateTime(2026, 7, 10, 8, 0)),
      urine('b', DateTime(2026, 7, 10, 20, 30)),
      stool('c', DateTime(2026, 7, 10, 12, 0)),
    ];
    final counts = aggregator.aggregateDailyCounts(records);
    expect(counts, {DateTime(2026, 7, 10): 3});
  });

  test('records spanning multiple days produce one entry per day', () {
    final records = [
      urine('a', DateTime(2026, 7, 10)),
      urine('b', DateTime(2026, 7, 11)),
      urine('c', DateTime(2026, 7, 11)),
      stool('d', DateTime(2026, 7, 12)),
    ];
    final counts = aggregator.aggregateDailyCounts(records);
    expect(counts, {
      DateTime(2026, 7, 10): 1,
      DateTime(2026, 7, 11): 2,
      DateTime(2026, 7, 12): 1,
    });
  });

  test('days with zero records are simply absent from the map', () {
    final records = [urine('a', DateTime(2026, 7, 10)), urine('b', DateTime(2026, 7, 12))];
    final counts = aggregator.aggregateDailyCounts(records);
    expect(counts.containsKey(DateTime(2026, 7, 11)), isFalse);
    expect(counts.length, 2);
  });

  test('an optional type filter restricts counting to that ToiletType', () {
    final records = [
      urine('a', DateTime(2026, 7, 10)),
      stool('b', DateTime(2026, 7, 10)),
      stool('c', DateTime(2026, 7, 10)),
    ];
    final urineOnly = aggregator.aggregateDailyCounts(records, type: ToiletType.urine);
    final stoolOnly = aggregator.aggregateDailyCounts(records, type: ToiletType.stool);
    expect(urineOnly, {DateTime(2026, 7, 10): 1});
    expect(stoolOnly, {DateTime(2026, 7, 10): 2});
  });
}
