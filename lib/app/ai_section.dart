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
import '../shared/utils/calendar_period.dart';

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

/// Pulls the trailing 3 calendar months of Agent B's weight/toilet records
/// and maps them into features/ai's self-contained [MonthlyReportInputStats]
/// shape. That class's doc comment is explicit that "whatever screen
/// assembles a report is responsible for pulling the real numbers out of
/// Agent B's ... records and mapping them into this shape" -- this widget
/// is that mapping, not a stub.
///
/// Uses [trailingCalendarMonthsStart] -- the same calendar-month arithmetic
/// as the weight trend chart's "3ヶ月" period -- rather than a fixed
/// `Duration`, so the two features agree on what "3 months" means (a fixed
/// 90-day window lands a few days off from a true 3-months-ago date, since
/// calendar months vary from 28-31 days). 3 months (not 1) deliberately:
/// weight is typically logged roughly monthly, not daily, so a 1-month
/// window usually contains at most one point -- not enough to draw a "推移"
/// (trend) at all.
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
    final periodStart = trailingCalendarMonthsStart(periodEnd, 3);

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

    final urineCounts = _aggregator.aggregateDailyCounts(
      toiletRecords,
      type: ToiletType.urine,
    );
    final stoolCounts = _aggregator.aggregateDailyCounts(
      toiletRecords,
      type: ToiletType.stool,
    );
    final days =
        {...urineCounts.keys, ...stoolCounts.keys}
            .where(
              (day) => !day.isBefore(periodStart) && !day.isAfter(periodEnd),
            )
            .toList()
          ..sort();
    final toiletCountsByDay = [
      for (final day in days)
        ToiletDayCount(
          date: day,
          count: (urineCounts[day] ?? 0) + (stoolCounts[day] ?? 0),
          urineCount: urineCounts[day] ?? 0,
          stoolCount: stoolCounts[day] ?? 0,
        ),
    ];

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
