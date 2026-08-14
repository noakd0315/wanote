import 'package:equatable/equatable.dart';

/// Which daily_record collection a [ConsultationReferenceRecord] points to.
/// Mirrors the three record types from spec sections 2-4.
enum ConsultationRecordType {
  healthRecord,
  weightRecord,
  toiletRecord;

  String get wireName => name;
}

/// The interface boundary between Agent B (daily_record) and Agent D (ai),
/// per docs/dog_health_app_spec.md section 6.2 ("トイレ記録・体重記録からの
/// タグ引用も可能にする") and section 6.3's `referenced_records` field.
///
/// Agent B constructs these from its own record documents; Agent D only
/// depends on this shape, never on daily_record's internal models, so the
/// two features can evolve independently.
class ConsultationReferenceRecord extends Equatable {
  const ConsultationReferenceRecord({
    required this.recordId,
    required this.recordType,
    required this.petId,
    required this.recordedAt,
    required this.label,
    this.tags = const [],
  });

  /// ID of the underlying health/weight/toilet record document.
  final String recordId;
  final ConsultationRecordType recordType;
  final String petId;
  final DateTime recordedAt;

  /// Short human-readable summary shown as a chip in the consultation
  /// screen, e.g. "軟便 2026-07-28" or "体重 12.4kg (7/28)".
  final String label;

  /// Free-form tags carried over from the source record (e.g. health record
  /// category tags, or stool condition) so the AI prompt has more context.
  final List<String> tags;

  @override
  List<Object?> get props => [
    recordId,
    recordType,
    petId,
    recordedAt,
    label,
    tags,
  ];
}

/// Why daily_record is suggesting the user open an AI consultation, and the
/// record that triggered it. Emitted by the anomaly-detection logic in
/// features/daily_record and rendered as a banner/CTA there; consumed by
/// features/ai only through [reference].
enum ConsultationSuggestionReason { bloodInStoolSuspected, prolongedDiarrhea }

class ConsultationSuggestion extends Equatable {
  const ConsultationSuggestion({
    required this.reason,
    this.streakDayCount,
    required this.message,
    required this.reference,
  });

  final ConsultationSuggestionReason reason;

  /// Kept for tests and logs. **Not for display** -- it is written in one
  /// fixed language, which is exactly how the warning banner ended up
  /// Japanese in the English app. The screen builds its own text from
  /// [reason] and [streakDayCount].
  final String message;

  /// How many consecutive days the streak ran, for the reasons that have
  /// one. Null otherwise.
  final int? streakDayCount;
  final ConsultationReferenceRecord reference;

  @override
  List<Object?> get props => [reason, message, streakDayCount, reference];
}
