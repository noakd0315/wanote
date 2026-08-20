import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/weight_record_repository.dart';
import '../domain/weight_trend_calculator.dart';
import '../models/weight_record.dart';
import '../../../shared/utils/formatting.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';

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
    this.onUpdateProfileWeight,
  });

  final String uid;
  final String petId;

  /// Writes a new weight onto the pet's own profile, if the app shell
  /// supplied a way to.
  ///
  /// A callback rather than a repository: the profile belongs to
  /// features/auth, and features/daily_record must not reach into it
  /// (wanote/.claude/CLAUDE.md). The shell owns both and does the wiring,
  /// exactly as it already does for the AI-consultation hand-off.
  final Future<void> Function(double weightKg)? onUpdateProfileWeight;
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

  /// Newest row at the top, or oldest (PM request, 2026-08-18).
  ///
  /// Newest-first answers "what is it now", which is the usual question, so
  /// it stays the default. Oldest-first answers "how has it gone", which is
  /// the question the moment someone picks すべて -- and until now there was
  /// no way to ask it without scrolling to the bottom.
  bool _newestFirst = true;
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
    final result =
        await showDialog<({DateTime date, double weightKg, bool updateProfile})>(
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
    await _updateProfileWeightIfAsked(result.updateProfile, result.weightKg);
  }

  /// Copies the weight onto the pet's profile, when the owner asked for it.
  ///
  /// Runs after the record is stored, and its failure never fails the save:
  /// the measurement is the thing that must not be lost, and the profile
  /// figure can be corrected on the pet's own form. Saying which half
  /// succeeded is better than a bare error over a record that is safely
  /// written.
  Future<void> _updateProfileWeightIfAsked(bool asked, double weightKg) async {
    final update = widget.onUpdateProfileWeight;
    if (!asked || update == null) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      await update(weightKg);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.weightProfileUpdateFailed)),
      );
    }
  }

  /// Opens a saved measurement for correction (PM request, 2026-08-18).
  ///
  /// A weight is typed in a hurry beside a wriggling dog, and a wrong one
  /// distorts every delta and the whole chart after it. Until now the only
  /// way to correct it was to add another record for the same date, which
  /// left the wrong number in the history.
  Future<void> _editEntry(WeightRecord record) async {
    final result =
        await showDialog<({DateTime date, double weightKg, bool updateProfile})>(
      context: context,
      builder: (context) => _WeightEntryDialog(existing: record),
    );
    if (result == null) return;
    await widget.repository.update(
      widget.uid,
      WeightRecord(
        weightId: record.weightId,
        petId: record.petId,
        measuredAt: result.date,
        weightKg: result.weightKg,
      ),
    );
    await _updateProfileWeightIfAsked(result.updateProfile, result.weightKg);
  }

  Future<void> _deleteEntry(WeightRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.weightDeleteConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.delete(widget.uid, record);
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
          if (_showTable)
            IconButton(
              tooltip: _newestFirst
                  ? l10n.weightSortOldestFirstTooltip
                  : l10n.weightSortNewestFirstTooltip,
              icon: Icon(
                _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              onPressed: () => setState(() => _newestFirst = !_newestFirst),
            ),
        ],
      ),
      body: StreamBuilder<List<WeightRecord>>(
        stream: widget.repository.watchAll(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return WanoteLoadingIndicator.centered();
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
                  // No check mark on the selected segment. The icon is laid
                  // out inside the segment, so it widened whichever one was
                  // selected and pushed its neighbours along -- the buttons
                  // appeared to resize as you tapped between them (PM
                  // report, 2026-08-17). Selection is already obvious from
                  // the filled background.
                  showSelectedIcon: false,
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
                    ButtonSegment(
                      value: WeightTrendPeriod.all,
                      label: Text(l10n.weightPeriodAll),
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
                    ? _WeightRecordTable(
                        series: trend.series,
                        newestFirst: _newestFirst,
                        onEdit: _editEntry,
                        onDelete: _deleteEntry,
                      )
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
  const _WeightRecordTable({
    required this.series,
    required this.newestFirst,
    required this.onEdit,
    required this.onDelete,
  });

  final List<WeightRecord> series;
  final bool newestFirst;
  final void Function(WeightRecord record) onEdit;
  final void Function(WeightRecord record) onDelete;

  @override
  Widget build(BuildContext context) {
    // series arrives ascending by date, which is what the chart plots.
    final rows = newestFirst ? series.reversed.toList() : series;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = rows[index];
        // The delta is always "against the previous measurement", so which
        // neighbouring row that is depends on the direction being read.
        final previousIndex = newestFirst ? index + 1 : index - 1;
        final previous = (previousIndex >= 0 && previousIndex < rows.length)
            ? rows[previousIndex]
            : null;
        final delta = previous == null
            ? null
            : record.weightKg - previous.weightKg;
        // Tap opens the record, a delete button sits at the end of the row
        // -- the same shape the toilet timeline uses (PM: 統一してほしい,
        // 2026-08-18). Delete was on a long-press, which is invisible: you
        // have to already know it is there.
        return ListTile(
          onTap: () => onEdit(record),
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
                  '${delta >= 0 ? '+' : ''}'
                  '${delta.toStringAsFixed(weightDecimalPlaces)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: delta > 0
                        ? Colors.redAccent
                        : (delta < 0 ? Colors.blueAccent : Colors.grey),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(record),
              ),
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
  const _WeightEntryDialog({this.existing});

  /// The record being edited, or null when adding a new one.
  final WeightRecord? existing;

  @override
  State<_WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<_WeightEntryDialog> {
  late DateTime _date = widget.existing?.measuredAt ?? DateTime.now();
  final _weightController = TextEditingController();

  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefilled here rather than in initState: the field is labelled in the
    // reader's unit, and working out which one needs a BuildContext.
    if (_prefilled) return;
    _prefilled = true;
    _weightController.text = weightInputText(
      context,
      widget.existing?.weightKg,
    );
  }

  /// Off by default (PM, 2026-08-21). A record is a measurement on a date;
  /// the profile weight is the figure the feeding calculator and the AI use.
  /// Correcting an old entry, or logging a weigh-in at the clinic that is
  /// not today's, should not silently move it.
  bool _updateProfile = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.weightEntryDialogTitle
            : l10n.weightEditDialogTitle,
      ),
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: _updateProfile,
            onChanged: (v) => setState(() => _updateProfile = v ?? false),
            title: Text(l10n.weightAlsoUpdateProfile),
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
            Navigator.of(context).pop((
              date: _date,
              weightKg: weight,
              updateProfile: _updateProfile,
            ));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
