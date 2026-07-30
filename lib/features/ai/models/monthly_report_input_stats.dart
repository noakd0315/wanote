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
class ToiletDayCount extends Equatable {
  const ToiletDayCount({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  List<Object?> get props => [date, count];
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
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<WeightSample> weightSamples;
  final List<ToiletDayCount> toiletCountsByDay;

  @override
  List<Object?> get props => [periodStart, periodEnd, weightSamples, toiletCountsByDay];
}
