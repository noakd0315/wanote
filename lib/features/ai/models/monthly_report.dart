import 'package:equatable/equatable.dart';

/// A generated monthly AI health-report summary, per spec 7.3's data model.
/// Field names in [toMap]/[fromMap] match the spec's snake_case columns
/// (report_id, pet_id, period_start, period_end, summary_text,
/// generated_at).
class MonthlyReport extends Equatable {
  const MonthlyReport({
    required this.reportId,
    required this.petId,
    required this.periodStart,
    required this.periodEnd,
    required this.summaryText,
    required this.generatedAt,
  });

  final String reportId;
  final String petId;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// AI-generated text summary (spec 7.2 example: "今月は体重が◯kg増加しま
  /// した。トイレの回数は先月と比べ◯回減少しています").
  final String summaryText;
  final DateTime generatedAt;

  Map<String, dynamic> toMap() => {
    'report_id': reportId,
    'pet_id': petId,
    'period_start': _dateOnly(periodStart),
    'period_end': _dateOnly(periodEnd),
    'summary_text': summaryText,
    'generated_at': generatedAt.toIso8601String(),
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory MonthlyReport.fromMap(Map<String, dynamic> map) {
    return MonthlyReport(
      reportId: map['report_id'] as String,
      petId: map['pet_id'] as String,
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: DateTime.parse(map['period_end'] as String),
      summaryText: map['summary_text'] as String,
      generatedAt: DateTime.parse(map['generated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    reportId,
    petId,
    periodStart,
    periodEnd,
    summaryText,
    generatedAt,
  ];
}
