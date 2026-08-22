import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ai_answer_text.dart';
import '../../../shared/services/ai_usage_repository.dart';
import '../data/report_repository.dart';
import '../domain/monthly_report_generator.dart';
import '../models/monthly_report.dart';
import '../models/monthly_report_input_stats.dart';
import 'widgets/disclaimer_banner.dart';
import 'widgets/upgrade_prompt_card.dart';
import '../../../shared/utils/formatting.dart';
import '../../../shared/widgets/stream_error_view.dart';
import '../../../shared/widgets/full_screen_wait.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';

enum _SummaryState { idle, loading, ready, needsUpgrade, error }

/// AI health report screen (spec 7.2). Graphs are visible to every user;
/// the AI text summary is generated on demand via an explicit "generate now"
/// button (spec 7.4 wants monthly-batch generation eventually — see this
/// repo's agent report for the follow-up Cloudflare Cron work) and is gated
/// to premium subscribers per the decision recorded there:
/// `hasUnlimitedSubscription` gates the AI summary text only, never the
/// underlying graphs.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.stats,
    required this.usageRepository,
    required this.reportGenerator,
    required this.reportRepository,
    required this.onRequestUpgrade,
    this.petName,
    this.opened,
  });

  final String uid;
  final String petId;
  final MonthlyReportInputStats stats;
  final AiUsageRepository usageRepository;
  final MonthlyReportGenerator reportGenerator;
  final ReportRepository reportRepository;

  /// Stub navigation hook for Agent E's subscription-upgrade UI.
  final VoidCallback onRequestUpgrade;
  final String? petName;

  /// Ticks when the AI section is opened.
  ///
  /// The summary stayed on screen for good once generated, so returning to
  /// the tab showed an old report with no way to ask for a new one (PM,
  /// 2026-08-21). Past reports are in the history below, so nothing is lost
  /// by clearing the inline copy.
  final ValueNotifier<int>? opened;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  _SummaryState _state = _SummaryState.idle;
  String? _summaryText;

  @override
  void initState() {
    super.initState();
    widget.opened?.addListener(_clearOnReopen);
  }

  @override
  void dispose() {
    widget.opened?.removeListener(_clearOnReopen);
    super.dispose();
  }

  void _clearOnReopen() {
    if (!mounted) return;
    if (_state == _SummaryState.loading) return;
    if (_state == _SummaryState.idle) return;
    setState(() {
      _state = _SummaryState.idle;
      _summaryText = null;
    });
  }

  Future<void> _generateSummary() async {
    // Captured before the first await: reading it from the
    // BuildContext afterwards would be a use-after-dispose hazard.
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() => _state = _SummaryState.loading);
    try {
      final status = await widget.usageRepository.getStatus(widget.uid);
      if (!status.hasUnlimitedSubscription) {
        setState(() => _state = _SummaryState.needsUpgrade);
        return;
      }
      final summary = await widget.reportGenerator.generateSummary(
        petId: widget.petId,
        stats: widget.stats,
        languageCode: languageCode,
      );
      await widget.reportRepository.save(
        uid: widget.uid,
        petId: widget.petId,
        periodStart: widget.stats.periodStart,
        periodEnd: widget.stats.periodEnd,
        summaryText: summary,
      );
      setState(() {
        _summaryText = summary;
        _state = _SummaryState.ready;
      });
    } catch (_) {
      setState(() => _state = _SummaryState.error);
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
      appBar: AppBar(title: Text(l10n.reportAppBarTitle)),
      body: Stack(
        children: [
          _buildBody(l10n),
          // The same wait the food-portion screen shows (PM, 2026-08-23).
          if (_state == _SummaryState.loading) const FullScreenWait(),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.reportPeriodLabel(
            _fullDateLabel(widget.stats.periodStart),
            _fullDateLabel(widget.stats.periodEnd),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.reportWeightTrendTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 180, child: _buildWeightChart(l10n)),
        const SizedBox(height: 24),
        Text(
          l10n.reportToiletTrendTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 180, child: _buildToiletChart(l10n)),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          l10n.reportAiSummaryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const DisclaimerBanner(),
        const SizedBox(height: 12),
        _buildSummarySection(l10n),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          l10n.reportHistoryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildHistory(l10n),
      ],
    );
  }

  /// Past reports, listed on the screen that produced them.
  ///
  /// They were being written to Firestore and never read back -- nothing
  /// called `watchReports`, so a report was visible once and then gone (PM,
  /// 2026-08-19). They belong here rather than in the consultation history:
  /// the report is a premium feature and that list is not, so mixing them
  /// puts a locked feature's output among a free one's (PM, 2026-08-20).
  ///
  /// Same shape as the consultation history deliberately (PM request): a
  /// card per entry, truncated preview, tap for the whole thing, delete on
  /// the row.
  Widget _buildHistory(AppLocalizations l10n) {
    return StreamBuilder<List<MonthlyReport>>(
      stream: widget.reportRepository.watchReports(widget.uid, widget.petId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamErrorView(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: WanoteLoadingIndicator.centered(),
          );
        }
        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.reportHistoryEmptyMessage),
          );
        }
        return Column(
          children: reports
              .map(
                (report) => Card(
                  child: ListTile(
                    onTap: () => _showReport(report),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.reportHistoryDeleteButton,
                      onPressed: () => _confirmDelete(report),
                    ),
                    title: Text(_periodLabel(report)),
                    subtitle: Text(
                      // Plain, not rendered: a heading at heading size
                      // inside a three-line snippet reads worse, but the
                      // markers should not show either.
                      aiAnswerPlainText(report.summaryText),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _periodLabel(MonthlyReport report) =>
      '${_fullDateLabel(report.periodStart)} - '
      '${_fullDateLabel(report.periodEnd)}';

  Future<void> _showReport(MonthlyReport report) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reportHistoryDetailTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reportHistoryPeriodLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(_periodLabel(report)),
              const SizedBox(height: 16),
              Text(
                l10n.reportHistorySummaryLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // Selectable for the same reason as a consultation answer:
              // something worth keeping is worth copying to the clinic.
              AiAnswerText(report.summaryText, selectable: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(MonthlyReport report) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.reportHistoryDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reportHistoryDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.reportRepository.delete(
      uid: widget.uid,
      petId: widget.petId,
      reportId: report.reportId,
    );
  }

  Widget _buildSummarySection(AppLocalizations l10n) {
    switch (_state) {
      case _SummaryState.idle:
      case _SummaryState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_state == _SummaryState.error)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.reportGenerationFailedMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            FilledButton(
              onPressed: _generateSummary,
              child: Text(l10n.reportGenerateSummaryButton),
            ),
          ],
        );
      case _SummaryState.loading:
        // Nothing here: the wait covers the whole screen instead.
        return const SizedBox.shrink();
      case _SummaryState.needsUpgrade:
        return UpgradePromptCard(
          message: l10n.reportSummaryUsageLimitMessage,
          onUpgrade: widget.onRequestUpgrade,
        );
      case _SummaryState.ready:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AiAnswerText(_summaryText ?? ''),
        );
    }
  }

  Widget _buildWeightChart(AppLocalizations l10n) {
    final samples = widget.stats.weightSamples;
    if (samples.isEmpty) {
      return Center(child: Text(l10n.reportNoWeightDataMessage));
    }
    final spots = <FlSpot>[
      for (var i = 0; i < samples.length; i++)
        FlSpot(i.toDouble(), samples[i].weightKg),
    ];
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            // A single-point series (common for a fresh account) is
            // otherwise completely invisible with no dot and no line to
            // draw -- always show the dot so there's something to see.
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          // fl_chart's FlTitlesData defaults *every* side (including top
          // and right) to showTitles: true with its own auto-computed
          // interval -- left unset, that leaked a second, uncoordinated set
          // of (sometimes fractional) numbers on the top/right edges of
          // every chart in this app. Explicitly hidden here and in
          // _buildToiletChart/ToiletFrequencyChartScreen.
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              // Forces one tick per data point (fl_chart's default interval
              // guess otherwise tries to space ticks evenly across the
              // value range, which for a handful of points rounds several
              // different tick positions to the same nearest sample --
              // showing the same date repeated).
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= samples.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _dateLabel(samples[index].date),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(weightDecimalPlaces)}kg',
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Urine and stool render as two side-by-side bars per day (rather than
  /// one combined bar) so each is distinguishable at a glance, per the PM's
  /// request -- same [_ToiletTypeLegend] used by ToiletFrequencyChartScreen.
  Widget _buildToiletChart(AppLocalizations l10n) {
    final counts = widget.stats.toiletCountsByDay;
    if (counts.isEmpty) {
      return Center(child: Text(l10n.reportNoToiletDataMessage));
    }
    final groups = <BarChartGroupData>[
      for (var i = 0; i < counts.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: counts[i].urineCount.toDouble(),
              color: Colors.blue,
              width: 6,
            ),
            BarChartRodData(
              toY: counts[i].stoolCount.toDouble(),
              color: Colors.brown,
              width: 6,
            ),
          ],
        ),
    ];
    return Column(
      children: [
        _ToiletTypeLegend(l10n: l10n),
        const SizedBox(height: 4),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: groups,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= counts.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _dateLabel(counts[index].date),
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                // Toilet visits are a whole-number count -- force
                // integer-only ticks, same fix applied to
                // ToiletFrequencyChartScreen.
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
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Zero-padded to match WeightRecordChartScreen's DateFormat('yyyy/MM/dd')
  // range label -- the two screens previously formatted the same kind of
  // date range differently (this one without zero-padding), which read as
  // a mismatch even once the underlying period calculation was unified.
  String _fullDateLabel(DateTime d) => formatDate(context, d);

  /// Short axis-tick format -- the full "対象期間" line already states the
  /// year, so repeating it on every X-axis tick would just crowd the chart.
  String _dateLabel(DateTime d) => '${d.month}/${d.day}';
}

/// Small color-key row so the two bars in [_ReportScreenState._buildToiletChart]
/// are identifiable without guessing -- same colors/labels as
/// ToiletFrequencyChartScreen's identical legend.
class _ToiletTypeLegend extends StatelessWidget {
  const _ToiletTypeLegend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: Colors.blue, label: l10n.reportUrineLegendLabel),
        const SizedBox(width: 16),
        _LegendDot(color: Colors.brown, label: l10n.reportStoolLegendLabel),
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
