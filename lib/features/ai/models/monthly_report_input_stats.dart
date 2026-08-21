import 'package:equatable/equatable.dart';

/// One weight measurement in the reporting period. Mirrors the shape of
/// Agent B's weight_records (spec 3.3) but is defined here, self-contained,
/// so features/ai never imports lib/features/daily_record/ directly —
/// whatever screen wires the report flow together is responsible for
/// mapping daily_record's own model into this one.
class WeightSample extends Equatable {
  const WeightSample({required this.date, required this.weightKg});

  final DateTime date;
  final double weightKg;

  @override
  List<Object?> get props => [date, weightKg];
}

/// Number of toilet-record entries (spec 4.3) on a given calendar day.
/// [urineCount]/[stoolCount] split [count] by record type so the report
/// chart can show urine vs. stool at a glance (PM request: "排尿と排便の
/// それぞれがパッと見て分かるようにしたい") -- [count] (their sum) is kept
/// as its own field since it's already what gets sent to the `/ai/report`
/// backend route for the AI summary's total-visits math.
class ToiletDayCount extends Equatable {
  const ToiletDayCount({
    required this.date,
    required this.count,
    required this.urineCount,
    required this.stoolCount,
  });

  final DateTime date;
  final int count;
  final int urineCount;
  final int stoolCount;

  @override
  List<Object?> get props => [date, count, urineCount, stoolCount];
}

/// Self-contained input shape for [MonthlyReportGenerator] and the backend
/// `/ai/report` route. Whatever screen assembles a report is responsible for
/// pulling the real numbers out of Agent B's weight/toilet records and
/// mapping them into this shape — features/ai only depends on this, not on
/// daily_record's internals.
class MonthlyReportInputStats extends Equatable {
  const MonthlyReportInputStats({
    required this.periodStart,
    required this.periodEnd,
    required this.weightSamples,
    required this.toiletCountsByDay,
    this.visits = const [],
    this.healthTagCounts = const [],
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<WeightSample> weightSamples;
  final List<ToiletDayCount> toiletCountsByDay;

  /// Vet visits inside the period, oldest first.
  ///
  /// Numbers alone made the report read as a page of statistics with nothing
  /// happening in it (PM, 2026-08-21: 情報として薄い). A visit is the event
  /// the numbers move around.
  final List<ReportVisit> visits;

  /// How many times each health-record tag was used in the period.
  ///
  /// Counts, not the records themselves: the summary is about what kept
  /// recurring, and every individual entry would crowd out the figures.
  final List<HealthTagCount> healthTagCounts;

  @override
  List<Object?> get props => [
    periodStart,
    periodEnd,
    weightSamples,
    toiletCountsByDay,
    visits,
    healthTagCounts,
  ];
}

/// One vet visit, reduced to what a summary can use.
class ReportVisit extends Equatable {
  const ReportVisit({required this.date, this.hospitalName, this.diagnosis});

  final DateTime date;
  final String? hospitalName;
  final String? diagnosis;

  @override
  List<Object?> get props => [date, hospitalName, diagnosis];
}

/// How often one health-record tag was used.
class HealthTagCount extends Equatable {
  const HealthTagCount({required this.tag, required this.count});

  /// The tag's wire name, not its label. The prompt is English and the
  /// answer's language is pinned separately -- sending the display text
  /// would put the reader's language inside the prompt.
  final String tag;
  final int count;

  @override
  List<Object?> get props => [tag, count];
}
