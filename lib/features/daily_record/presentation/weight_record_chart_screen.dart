import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/weight_record_repository.dart';
import '../domain/weight_trend_calculator.dart';
import '../models/weight_record.dart';

/// Spec 3.2: line chart with a 1 month / 3 months / 1 year period toggle,
/// plus the "前回比" / "1ヶ月前比" delta display from spec 3.4. The actual
/// filtering/delta math lives in [WeightTrendCalculator] (pure, unit
/// tested) — this widget only renders its result.
class WeightRecordChartScreen extends StatefulWidget {
  const WeightRecordChartScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
  });

  final String uid;
  final String petId;
  final WeightRecordRepository repository;

  @override
  State<WeightRecordChartScreen> createState() => _WeightRecordChartScreenState();
}

class _WeightRecordChartScreenState extends State<WeightRecordChartScreen> {
  WeightTrendPeriod _period = WeightTrendPeriod.oneMonth;
  static const _calculator = WeightTrendCalculator();

  Future<void> _addEntry() async {
    final result = await showDialog<({DateTime date, double weightKg})>(
      context: context,
      builder: (context) => const _WeightEntryDialog(),
    );
    if (result == null) return;

    final existing = await widget.repository.findForDate(widget.uid, widget.petId, result.date);
    var overwriteTargetId = existing.isNotEmpty ? existing.first.weightId : null;

    if (existing.isNotEmpty && mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('同じ日の記録があります'),
          content: const Text('上書きしますか？それとも追加で記録しますか？（同日に複数回記録された場合の扱い、spec 3.4）'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop('append'), child: const Text('追加する')),
            TextButton(onPressed: () => Navigator.of(context).pop('overwrite'), child: const Text('上書きする')),
          ],
        ),
      );
      if (choice != 'overwrite') overwriteTargetId = null;
    }

    if (overwriteTargetId != null) {
      await widget.repository.update(
        widget.uid,
        WeightRecord(
          weightId: overwriteTargetId,
          petId: widget.petId,
          measuredAt: result.date,
          weightKg: result.weightKg,
        ),
      );
    } else {
      await widget.repository.create(
        uid: widget.uid,
        petId: widget.petId,
        measuredAt: result.date,
        weightKg: result.weightKg,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('体重記録')),
      body: StreamBuilder<List<WeightRecord>>(
        stream: widget.repository.watchAll(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <WeightRecord>[];
          final trend = _calculator.calculate(records: records, now: DateTime.now(), period: _period);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<WeightTrendPeriod>(
                  segments: const [
                    ButtonSegment(value: WeightTrendPeriod.oneMonth, label: Text('1ヶ月')),
                    ButtonSegment(value: WeightTrendPeriod.threeMonths, label: Text('3ヶ月')),
                    ButtonSegment(value: WeightTrendPeriod.oneYear, label: Text('1年')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (selection) => setState(() => _period = selection.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DeltaBadge(label: '前回比', delta: trend.deltaVsPrevious),
                    _DeltaBadge(label: '1ヶ月前比', delta: trend.deltaVsOneMonthAgo),
                  ],
                ),
              ),
              Expanded(
                child: trend.series.isEmpty
                    ? const Center(child: Text('この期間の記録がありません'))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < trend.series.length; i++)
                                    FlSpot(i.toDouble(), trend.series[i].weightKg),
                                ],
                                isCurved: false,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.round();
                                    if (index < 0 || index >= trend.series.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      DateFormat('M/d').format(trend.series[index].measuredAt),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.label, required this.delta});

  final String label;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final text = delta == null ? '-' : '${delta! >= 0 ? '+' : ''}${delta!.toStringAsFixed(1)}kg';
    final color = delta == null
        ? null
        : (delta! > 0 ? Colors.redAccent : (delta! < 0 ? Colors.blueAccent : null));
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _WeightEntryDialog extends StatefulWidget {
  const _WeightEntryDialog();

  @override
  State<_WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<_WeightEntryDialog> {
  DateTime _date = DateTime.now();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('体重を記録'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日付'),
            subtitle: Text(DateFormat('yyyy/MM/dd').format(_date)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '体重 (kg)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final weight = double.tryParse(_weightController.text);
            if (weight == null) return;
            Navigator.of(context).pop((date: _date, weightKg: weight));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
