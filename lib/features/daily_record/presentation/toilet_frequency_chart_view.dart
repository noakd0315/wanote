import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/toilet_record_repository.dart';
import '../domain/toilet_frequency_aggregator.dart';
import '../models/toilet_record.dart';
import '../../../shared/utils/formatting.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';

/// Spec 4.2: "頻度グラフ（日別回数の推移）". Bucketing is done by the pure,
/// unit-tested [ToiletFrequencyAggregator] — this widget only renders bars
/// for the most recent 14 days present in that result.
///
/// Body only, no Scaffold: it is swapped in place of the timeline list
/// inside ToiletRecordTimelineScreen rather than pushed as its own screen.
/// Pushing it used to replace that screen's AppBar with one that had no
/// actions, so the button that got you there vanished (PM report:
/// "グラフ表示をすると、ヘッダー部のメニューが消えてしまいます"). The weight
/// screen already toggled chart/table in place; this now matches it.
class ToiletFrequencyChartView extends StatelessWidget {
  const ToiletFrequencyChartView({
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
    return StreamBuilder<List<ToiletRecord>>(
      stream: repository.watchTimeline(uid, petId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return WanoteLoadingIndicator.centered();
        }
        final records = snapshot.data ?? const <ToiletRecord>[];
        // Split by type (rather than one combined count) so urine and
        // stool are each distinguishable at a glance, per the PM's
        // request -- rendered as two side-by-side bars per day below.
        final urineCounts = _aggregator.aggregateDailyCounts(
          records,
          type: ToiletType.urine,
        );
        final stoolCounts = _aggregator.aggregateDailyCounts(
          records,
          type: ToiletType.stool,
        );

        final today = DateTime.now();
        final days = List.generate(
          _daysShown,
          (i) => DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(Duration(days: _daysShown - 1 - i)),
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _ToiletTypeLegend(),
              const SizedBox(height: 8),
              Expanded(
                child: BarChart(
                  BarChartData(
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: (urineCounts[days[i]] ?? 0).toDouble(),
                              color: Colors.blue,
                              width: 6,
                            ),
                            BarChartRodData(
                              toY: (stoolCounts[days[i]] ?? 0).toDouble(),
                              color: Colors.brown,
                              width: 6,
                            ),
                          ],
                        ),
                    ],
                    minY: 0,
                    titlesData: FlTitlesData(
                      // fl_chart's FlTitlesData defaults *every* side
                      // (including top and right) to showTitles: true
                      // with its own auto-computed interval -- left
                      // unset, that leaked a second, uncoordinated set of
                      // (sometimes fractional) numbers on the top/right
                      // edges of the chart.
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (index < 0 || index >= days.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              formatShortDate(context, days[index]),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      // Toilet visits are a whole-number count -- force
                      // integer-only ticks/labels so fl_chart's default
                      // "nice" interval (which can land on e.g. 2.5)
                      // never shows a fractional visit count.
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble()) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small color-key row so the two bars per day are identifiable without
/// guessing -- same colors/labels as the AI health report's identical
/// legend for its own urine/stool bar chart.
class _ToiletTypeLegend extends StatelessWidget {
  const _ToiletTypeLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: Colors.blue, label: l10n.toiletUrineLabel),
        const SizedBox(width: 16),
        _LegendDot(color: Colors.brown, label: l10n.toiletStoolLabel),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
