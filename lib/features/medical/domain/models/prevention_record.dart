import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Administration history (投与履歴) per spec 5.3. [petId] is intentionally
/// denormalized onto the record (spec: "記録一覧の検索を高速化するため非正規化
/// して保持") even though it's derivable via the parent [programId].
class PreventionRecord extends Equatable {
  const PreventionRecord({
    required this.recordId,
    required this.programId,
    required this.petId,
    required this.administeredAt,
    this.visitId,
    this.hospitalName,
    this.nextDueDate,
    this.certificateFile,
    this.ocrExtractedData,
    this.ocrConfidence,
  });

  final String recordId;
  final String programId;
  final String petId;
  final DateTime administeredAt;

  /// Links to a visit (5.1) if this administration happened during a
  /// hospital visit.
  final String? visitId;

  /// Free-text hospital name for self-administered doses not tied to a
  /// [visitId] (spec: "通院と紐付けない自宅投与の場合に単独入力").
  final String? hospitalName;

  /// monthly/annual programs get this auto-calculated (see
  /// [PreventionDueDateCalculator]); manual overwrite is allowed per spec.
  final DateTime? nextDueDate;

  /// Download URL for the certificate image/PDF in Firebase Storage.
  final String? certificateFile;

  /// Raw AI-OCR extraction result, stored regardless of confidence (spec
  /// 5.4 step 5).
  final Map<String, dynamic>? ocrExtractedData;
  final double? ocrConfidence;

  PreventionRecord copyWith({
    DateTime? administeredAt,
    String? visitId,
    String? hospitalName,
    DateTime? nextDueDate,
    bool clearNextDueDate = false,
    String? certificateFile,
    Map<String, dynamic>? ocrExtractedData,
    double? ocrConfidence,
  }) {
    return PreventionRecord(
      recordId: recordId,
      programId: programId,
      petId: petId,
      administeredAt: administeredAt ?? this.administeredAt,
      visitId: visitId ?? this.visitId,
      hospitalName: hospitalName ?? this.hospitalName,
      nextDueDate: clearNextDueDate ? null : (nextDueDate ?? this.nextDueDate),
      certificateFile: certificateFile ?? this.certificateFile,
      ocrExtractedData: ocrExtractedData ?? this.ocrExtractedData,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'program_id': programId,
      'pet_id': petId,
      'administered_at': Timestamp.fromDate(administeredAt),
      'visit_id': visitId,
      'hospital_name': hospitalName,
      'next_due_date': nextDueDate == null
          ? null
          : Timestamp.fromDate(nextDueDate!),
      'certificate_file': certificateFile,
      'ocr_extracted_data': ocrExtractedData,
      'ocr_confidence': ocrConfidence,
    };
  }

  factory PreventionRecord.fromMap(Map<String, dynamic> map) {
    return PreventionRecord(
      recordId: map['record_id'] as String,
      programId: map['program_id'] as String,
      petId: map['pet_id'] as String,
      administeredAt: _readDate(map['administered_at'])!,
      visitId: map['visit_id'] as String?,
      hospitalName: map['hospital_name'] as String?,
      nextDueDate: _readDate(map['next_due_date']),
      certificateFile: map['certificate_file'] as String?,
      ocrExtractedData: (map['ocr_extracted_data'] as Map?)
          ?.cast<String, dynamic>(),
      ocrConfidence: (map['ocr_confidence'] as num?)?.toDouble(),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  @override
  List<Object?> get props => [
    recordId,
    programId,
    petId,
    administeredAt,
    visitId,
    hospitalName,
    nextDueDate,
    certificateFile,
    ocrExtractedData,
    ocrConfidence,
  ];
}
