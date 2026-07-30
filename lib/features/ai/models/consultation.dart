import 'package:equatable/equatable.dart';

/// One AI-consultation round-trip, per spec 6.3's data model. Field names in
/// [toMap]/[fromMap] intentionally match the spec's snake_case column names
/// (consultation_id, pet_id, question_text, referenced_records, ai_response,
/// created_at) so the Firestore documents are self-describing.
class Consultation extends Equatable {
  const Consultation({
    required this.consultationId,
    required this.petId,
    required this.questionText,
    required this.aiResponse,
    required this.createdAt,
    this.referencedRecordIds = const [],
  });

  final String consultationId;
  final String petId;
  final String questionText;

  /// IDs of any daily_record documents (health/weight/toilet) the user
  /// attached as context, per spec 6.3's `referenced_records` column. Only
  /// the IDs are persisted; features/ai never stores a copy of Agent B's
  /// record content.
  final List<String> referencedRecordIds;
  final String aiResponse;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'consultation_id': consultationId,
    'pet_id': petId,
    'question_text': questionText,
    'referenced_records': referencedRecordIds,
    'ai_response': aiResponse,
    'created_at': createdAt.toIso8601String(),
  };

  factory Consultation.fromMap(Map<String, dynamic> map) {
    return Consultation(
      consultationId: map['consultation_id'] as String,
      petId: map['pet_id'] as String,
      questionText: map['question_text'] as String,
      referencedRecordIds:
          (map['referenced_records'] as List<dynamic>? ?? const [])
              .map((e) => e as String)
              .toList(),
      aiResponse: map['ai_response'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    consultationId,
    petId,
    questionText,
    referencedRecordIds,
    aiResponse,
    createdAt,
  ];
}
