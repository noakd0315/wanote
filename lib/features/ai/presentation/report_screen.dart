import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../shared/services/ai_usage_repository.dart';
import '../data/report_pdf_exporter.dart';
import '../data/report_repository.dart';
import '../domain/monthly_report_generator.dart';
import '../models/monthly_report_input_stats.dart';
import 'widgets/disclaimer_banner.dart';
import 'widgets/upgrade_prompt_card.dart';

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
    this.pdfExporter = const ReportPdfExporter(),
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
  final ReportPdfExporter pdfExporter;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  _SummaryState _state = _SummaryState.idle;
  String? _summaryText;

  Future<void> _generateSummary() async {
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

  Future<void> _exportPdf() async {
    await widget.pdfExporter.shareOrPrint(
      stats: widget.stats,
      summaryText: _summaryText,
      petName: widget.petName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI健康レポート'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDFで書き出す',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '対象期間: ${_dateLabel(widget.stats.periodStart)} 〜 ${_dateLabel(widget.stats.periodEnd)}',
          ),
          const SizedBox(height: 16),
          const Text('体重の推移', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: _buildWeightChart()),
          const SizedBox(height: 24),
          const Text('トイレ回数の推移', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: _buildToiletChart()),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text('AIサマリー', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const DisclaimerBanner(),
          const SizedBox(height: 12),
          _buildSummarySection(),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    switch (_state) {
      case _SummaryState.idle:
      case _SummaryState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_state == _SummaryState.error)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'レポート生成に失敗しました。もう一度お試しください。',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            FilledButton(
              onPressed: _generateSummary,
              child: const Text('AIサマリーを生成'),
            ),
          ],
        );
      case _SummaryState.loading:
        return const Center(child: CircularProgressIndicator());
      case _SummaryState.needsUpgrade:
        return UpgradePromptCard(
          message: 'AIサマリーは有料プラン限定機能です。'
              'グラフは無料版でも引き続きご覧いただけます。',
          onUpgrade: widget.onRequestUpgrade,
        );
      case _SummaryState.ready:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_summaryText ?? ''),
        );
    }
  }

  Widget _buildWeightChart() {
    final samples = widget.stats.weightSamples;
    if (samples.isEmpty) {
      return const Center(child: Text('体重の記録がありません。'));
    }
    final spots = <FlSpot>[
      for (var i = 0; i < samples.length; i++) FlSpot(i.toDouble(), samples[i].weightKg),
    ];
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, dotData: const FlDotData(show: false)),
        ],
        titlesData: const FlTitlesData(show: false),
      ),
    );
  }

  Widget _buildToiletChart() {
    final counts = widget.stats.toiletCountsByDay;
    if (counts.isEmpty) {
      return const Center(child: Text('トイレの記録がありません。'));
    }
    final groups = <BarChartGroupData>[
      for (var i = 0; i < counts.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: counts[i].count.toDouble())],
        ),
    ];
    return BarChart(
      BarChartData(barGroups: groups, titlesData: const FlTitlesData(show: false)),
    );
  }

  String _dateLabel(DateTime d) => '${d.year}/${d.month}/${d.day}';
}
