import 'package:flutter/material.dart';

import '../features/ai/data/ai_backend_client.dart';
import '../features/ai/data/consultation_repository.dart';
import '../features/ai/data/report_repository.dart';
import '../features/ai/domain/monthly_report_generator.dart';
import '../features/ai/models/monthly_report_input_stats.dart';
import '../features/ai/presentation/consultation_screen.dart';
import '../features/ai/presentation/report_screen.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../features/daily_record/domain/toilet_frequency_aggregator.dart';
import '../features/daily_record/models/toilet_record.dart';
import '../features/daily_record/models/weight_record.dart';
import '../shared/services/ai_usage_repository.dart';

/// AI相談 section of the app shell: combines Agent D's [ConsultationScreen]
/// and [ReportScreen] behind a small local segmented control, since neither
/// features/ai nor this app-shell has an umbrella "AI" screen to reuse
/// (mirrors DailyRecordSection's approach for daily_record's 3 screens).
class AiSection extends StatefulWidget {
  const AiSection({
    super.key,
    required this.uid,
    required this.petId,
    required this.petName,
    required this.usageRepository,
    required this.backendClient,
    required this.consultationRepository,
    required this.reportRepository,
    required this.reportGenerator,
    required this.weightRecordRepository,
    required this.toiletRecordRepository,
    required this.onRequestUpgrade,
  });

  final String uid;
  final String petId;
  final String petName;
  final AiUsageRepository usageRepository;
  final AiBackendClient backendClient;
  final ConsultationRepository consultationRepository;
  final ReportRepository reportRepository;
  final MonthlyReportGenerator reportGenerator;
  final WeightRecordRepository weightRecordRepository;
  final ToiletRecordRepository toiletRecordRepository;
  final VoidCallback onRequestUpgrade;

  @override
  State<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<AiSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('相談'),
                  icon: Icon(Icons.chat_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('レポート'),
                  icon: Icon(Icons.insert_chart_outlined),
                ),
              ],
              selected: {_selectedIndex},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedIndex = selection.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              ConsultationScreen(
                uid: widget.uid,
                petId: widget.petId,
                usageRepository: widget.usageRepository,
                backendClient: widget.backendClient,
                consultationRepository: widget.consultationRepository,
                onRequestUpgrade: widget.onRequestUpgrade,
              ),
              _MonthlyReportTab(
                uid: widget.uid,
                petId: widget.petId,
                petName: widget.petName,
                usageRepository: widget.usageRepository,
                reportRepository: widget.reportRepository,
                reportGenerator: widget.reportGenerator,
                weightRecordRepository: widget.weightRecordRepository,
                toiletRecordRepository: widget.toiletRecordRepository,
                onRequestUpgrade: widget.onRequestUpgrade,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pulls the trailing 90 days of Agent B's weight/toilet records and maps
/// them into features/ai's self-contained [MonthlyReportInputStats] shape.
/// That class's doc comment is explicit that "whatever screen assembles a
/// report is responsible for pulling the real numbers out of Agent B's ...
/// records and mapping them into this shape" -- this widget is that
/// mapping, not a stub. It uses a rolling window rather than calendar-month
/// boundaries since the spec doesn't pin the period down further; a real
/// "monthly" picker would be a reasonable follow-up.
///
/// 90 days (not 30) deliberately: weight is typically logged roughly
/// monthly, not daily, so a 30-day window usually contains at most one
/// point -- not enough to draw a "推移" (trend) at all. 90 days gives the
/// chart a realistic chance of showing more than a single dot.
class _MonthlyReportTab extends StatefulWidget {
  const _MonthlyReportTab({
    required this.uid,
    required this.petId,
    required this.petName,
    required this.usageRepository,
    required this.reportRepository,
    required this.reportGenerator,
    required this.weightRecordRepository,
    required this.toiletRecordRepository,
    required this.onRequestUpgrade,
  });

  final String uid;
  final String petId;
  final String petName;
  final AiUsageRepository usageRepository;
  final ReportRepository reportRepository;
  final MonthlyReportGenerator reportGenerator;
  final WeightRecordRepository weightRecordRepository;
  final ToiletRecordRepository toiletRecordRepository;
  final VoidCallback onRequestUpgrade;

  @override
  State<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<_MonthlyReportTab> {
  static const _aggregator = ToiletFrequencyAggregator();

  late final Future<MonthlyReportInputStats> _statsFuture = _loadStats();

  Future<MonthlyReportInputStats> _loadStats() async {
    final periodEnd = DateTime.now();
    final periodStart = periodEnd.subtract(const Duration(days: 90));

    final List<WeightRecord> weightRecords = await widget.weightRecordRepository
        .watchAll(widget.uid, widget.petId)
        .first;
    final List<ToiletRecord> toiletRecords = await widget.toiletRecordRepository
        .watchTimeline(widget.uid, widget.petId)
        .first;

    final weightSamples =
        weightRecords
            .where(
              (r) =>
                  !r.measuredAt.isBefore(periodStart) &&
                  !r.measuredAt.isAfter(periodEnd),
            )
            .map((r) => WeightSample(date: r.measuredAt, weightKg: r.weightKg))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final dailyCounts = _aggregator.aggregateDailyCounts(toiletRecords);
    final toiletCountsByDay =
        dailyCounts.entries
            .where(
              (e) => !e.key.isBefore(periodStart) && !e.key.isAfter(periodEnd),
            )
            .map((e) => ToiletDayCount(date: e.key, count: e.value))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return MonthlyReportInputStats(
      periodStart: periodStart,
      periodEnd: periodEnd,
      weightSamples: weightSamples,
      toiletCountsByDay: toiletCountsByDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyReportInputStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ReportScreen(
          uid: widget.uid,
          petId: widget.petId,
          petName: widget.petName,
          stats: snapshot.data!,
          usageRepository: widget.usageRepository,
          reportGenerator: widget.reportGenerator,
          reportRepository: widget.reportRepository,
          onRequestUpgrade: widget.onRequestUpgrade,
        );
      },
    );
  }
}
