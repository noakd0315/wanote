import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/weight_record_repository.dart';
import '../domain/weight_trend_calculator.dart';
import '../models/weight_record.dart';
import '../../../shared/utils/formatting.dart';

/// Spec 3.2: line chart with a 3 months / 6 months / 1 year period toggle,
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
  State<WeightRecordChartScreen> createState() =>
      _WeightRecordChartScreenState();
}

class _WeightRecordChartScreenState extends State<WeightRecordChartScreen> {
  /// Persisted so the chart/list toggle is a single shared preference rather
  /// than per-screen-instance state -- otherwise reaching this screen via
  /// the bottom-nav's 日常記録 tab vs. Home's 体重 shortcut would each keep
  /// their own independent (and easily out-of-sync) toggle, and the choice
  /// wouldn't survive leaving and re-entering either path. Defaults to the
  /// list view (per the PM's request) until the stored preference loads.
  static const _showTablePrefsKey = 'weight_chart.show_table';

  WeightTrendPeriod _period = WeightTrendPeriod.threeMonths;
  bool _showTable = true;
  static const _calculator = WeightTrendCalculator();

  @override
  void initState() {
    super.initState();
    _loadShowTablePreference();
  }

  Future<void> _loadShowTablePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_showTablePrefsKey);
    if (stored != null && mounted) {
      setState(() => _showTable = stored);
    }
  }

  Future<void> _setShowTable(bool value) async {
    setState(() => _showTable = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTablePrefsKey, value);
  }

  Future<void> _addEntry() async {
    final result = await showDialog<({DateTime date, double weightKg})>(
      context: context,
      builder: (context) => const _WeightEntryDialog(),
    );
    if (result == null) return;

    final existing = await widget.repository.findForDate(
      widget.uid,
      widget.petId,
      result.date,
    );
    var overwriteTargetId = existing.isNotEmpty
        ? existing.first.weightId
        : null;

    if (existing.isNotEmpty && mounted) {
      final l10n = AppLocalizations.of(context)!;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.weightDuplicateDateDialogTitle),
          content: Text(l10n.weightDuplicateDateDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('append'),
              child: Text(l10n.weightAddAsNewEntryButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('overwrite'),
              child: Text(l10n.weightOverwriteButtonLabel),
            ),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.weightRecordTimelineTitle),
        actions: [
          IconButton(
            tooltip: _showTable
                ? l10n.weightShowChartTooltip
                : l10n.weightShowTableTooltip,
            icon: Icon(
              _showTable ? Icons.show_chart : Icons.table_rows_outlined,
            ),
            onPressed: () => _setShowTable(!_showTable),
          ),
        ],
      ),
      body: StreamBuilder<List<WeightRecord>>(
        stream: widget.repository.watchAll(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <WeightRecord>[];
          final trend = _calculator.calculate(
            records: records,
            now: DateTime.now(),
            period: _period,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<WeightTrendPeriod>(
                  segments: [
                    ButtonSegment(
                      value: WeightTrendPeriod.threeMonths,
                      label: Text(l10n.weightPeriodThreeMonths),
                    ),
                    ButtonSegment(
                      value: WeightTrendPeriod.sixMonths,
                      label: Text(l10n.weightPeriodSixMonths),
                    ),
                    ButtonSegment(
                      value: WeightTrendPeriod.oneYear,
                      label: Text(l10n.weightPeriodOneYear),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (selection) =>
                      setState(() => _period = selection.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${formatDate(context, trend.periodStart)} 〜 '
                  '${formatDate(context, trend.periodEnd)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DeltaBadge(
                      label: l10n.weightDeltaVsPreviousLabel,
                      delta: trend.deltaVsPrevious,
                    ),
                    _DeltaBadge(
                      label: l10n.weightDeltaVsOneMonthAgoLabel,
                      delta: trend.deltaVsOneMonthAgo,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: trend.series.isEmpty
                    ? Center(child: Text(l10n.weightNoRecordsForPeriod))
                    : _showTable
                    ? _WeightRecordTable(series: trend.series)
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < trend.series.length; i++)
                                    FlSpot(
                                      i.toDouble(),
                                      trend.series[i].weightKg,
                                    ),
                                ],
                                isCurved: false,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              // fl_chart's FlTitlesData defaults *every*
                              // side (including top and right) to
                              // showTitles: true with its own
                              // auto-computed interval -- left unset, that
                              // leaked a second, uncoordinated set of
                              // numbers on the top/right edges of the
                              // chart (same fix applied to
                              // ToiletFrequencyChartScreen/ReportScreen).
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
                                    if (index < 0 ||
                                        index >= trend.series.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      DateFormat(
                                        'M/d',
                                      ).format(trend.series[index].measuredAt),
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

/// Tabular alternative to the line chart, newest entry first. Reuses the
/// same period-filtered [WeightTrendCalculator] output as the chart, so
/// both views always agree.
class _WeightRecordTable extends StatelessWidget {
  const _WeightRecordTable({required this.series});

  final List<WeightRecord> series;

  @override
  Widget build(BuildContext context) {
    final rows = series.reversed.toList();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = rows[index];
        // series is ascending by date; the row below (in display order) is
        // the chronologically-previous measurement.
        final previous = index + 1 < rows.length ? rows[index + 1] : null;
        final delta = previous == null
            ? null
            : record.weightKg - previous.weightKg;
        return ListTile(
          title: Text(formatDate(context, record.measuredAt)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatWeight(context, record.weightKg),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (delta != null) ...[
                const SizedBox(width: 12),
                Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: delta > 0
                        ? Colors.redAccent
                        : (delta < 0 ? Colors.blueAccent : Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.label, required this.delta});

  final String label;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final text = delta == null
        ? '-'
        : '${delta! >= 0 ? '+' : ''}${formatWeight(context, delta!)}';
    final color = delta == null
        ? null
        : (delta! > 0
              ? Colors.redAccent
              : (delta! < 0 ? Colors.blueAccent : null));
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.weightEntryDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.commonDateLabel),
            subtitle: Text(formatDate(context, _date)),
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
            decoration: InputDecoration(
              labelText: l10n.weightFieldLabelWithUnit(
                weightInputUnit(context),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            // Parsed through the same helper that labelled the field, so
            // a value typed in pounds is stored as kilograms. Records are
            // always kilograms: a stored unit that depended on the reader's
            // language would corrupt the history the moment they switched.
            final weight = parseWeightToKilograms(
              context,
              _weightController.text,
            );
            if (weight == null) return;
            Navigator.of(context).pop((date: _date, weightKg: weight));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
