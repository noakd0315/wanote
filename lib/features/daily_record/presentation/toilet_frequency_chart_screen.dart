import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/toilet_record_repository.dart';
import '../domain/toilet_frequency_aggregator.dart';
import '../models/toilet_record.dart';

/// Spec 4.2: "頻度グラフ（日別回数の推移）". Bucketing is done by the pure,
/// unit-tested [ToiletFrequencyAggregator] — this widget only renders bars
/// for the most recent 14 days present in that result.
class ToiletFrequencyChartScreen extends StatelessWidget {
  const ToiletFrequencyChartScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
  });

  final String uid;
  final String petId;
  final ToiletRecordRepository repository;

  static const _aggregator = ToiletFrequencyAggregator();
  static const _daysShown = 14;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トイレ頻度')),
      body: StreamBuilder<List<ToiletRecord>>(
        stream: repository.watchTimeline(uid, petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <ToiletRecord>[];
          final counts = _aggregator.aggregateDailyCounts(records);

          final today = DateTime.now();
          final days = List.generate(
            _daysShown,
            (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: _daysShown - 1 - i)),
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: BarChart(
              BarChartData(
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [BarChartRodData(toY: (counts[days[i]] ?? 0).toDouble())],
                    ),
                ],
                minY: 0,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                        return Text(DateFormat('M/d').format(days[index]), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  // Toilet visits are a whole-number count -- force
                  // integer-only ticks/labels so fl_chart's default "nice"
                  // interval (which can land on e.g. 2.5) never shows a
                  // fractional visit count.
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) return const SizedBox.shrink();
                        return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
