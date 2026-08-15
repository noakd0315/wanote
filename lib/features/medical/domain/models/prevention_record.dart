import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'medication.dart' show ReminderTime;

/// Administration history (投与履歴) per spec 5.3. [petId] is intentionally
/// denormalized onto the record (spec: "記録一覧の検索を高速化するため非正規化
/// して保持") even though it's derivable via the parent [programId].
class PreventionRecord extends Equatable {
  const PreventionRecord({
    required this.recordId,
    required this.programId,
    required this.petId,
    required this.administeredAt,
    this.productName,
    this.dosage,
    this.visitId,
    this.hospitalName,
    this.nextDueDate,
    this.reminderEnabled = false,
    this.reminderTime,
    this.certificateFile,
    this.ocrExtractedData,
    this.ocrConfidence,
  });

  final String recordId;
  final String programId;
  final String petId;
  final DateTime administeredAt;

  /// What was given: the vaccine type for a vaccination, the drug name for
  /// a medication (PM request -- the label the form shows differs, but both
  /// name the substance, so one field carries both).
  ///
  /// Free text: there are far too many vaccine combinations to offer a list
  /// (PM decision, 2026-08-15). This is also where the OCR's `product_name`
  /// lands, which the form previously read off the certificate and threw
  /// away for want of somewhere to put it.
  final String? productName;

  /// How much was given, in the owner's own words. Free text for the same
  /// reason a medication's dosage is: "1錠", "半分", "体重に合わせて2本" are
  /// all things a vet says, and none of them are a number (PM request: the
  /// same fields as any other medicine).
  final String? dosage;

  /// Links to a visit (5.1) if this administration happened during a
  /// hospital visit.
  final String? visitId;

  /// Free-text hospital name for self-administered doses not tied to a
  /// [visitId] (spec: "通院と紐付けない自宅投与の場合に単独入力").
  final String? hospitalName;

  /// monthly/annual programs get this auto-calculated (see
  /// [PreventionDueDateCalculator]); manual overwrite is allowed per spec.
  final DateTime? nextDueDate;

  /// Whether the next dose is worth a notification. Defaults to on, since
  /// the whole point of recording a due date is not to miss it -- but a
  /// finished course or a one-off vaccine does not need reminding about.
  final bool reminderEnabled;

  /// What time of day to remind, when [reminderEnabled].
  ///
  /// Null falls back to the scheduler's default hour. PM: a reminder that
  /// arrives just after midnight is no use to anyone, so the hour is the
  /// owner's to choose rather than a constant.
  final ReminderTime? reminderTime;

  /// Download URL for the certificate image/PDF in Firebase Storage.
  final String? certificateFile;

  /// Raw AI-OCR extraction result, stored regardless of confidence (spec
  /// 5.4 step 5).
  final Map<String, dynamic>? ocrExtractedData;
  final double? ocrConfidence;

  PreventionRecord copyWith({
    DateTime? administeredAt,
    String? productName,
    String? dosage,
    String? visitId,
    String? hospitalName,
    DateTime? nextDueDate,
    bool clearNextDueDate = false,
    bool? reminderEnabled,
    ReminderTime? reminderTime,
    String? certificateFile,
    Map<String, dynamic>? ocrExtractedData,
    double? ocrConfidence,
  }) {
    return PreventionRecord(
      recordId: recordId,
      programId: programId,
      petId: petId,
      administeredAt: administeredAt ?? this.administeredAt,
      productName: productName ?? this.productName,
      dosage: dosage ?? this.dosage,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
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
      'product_name': productName,
      'dosage': dosage,
      'reminder_enabled': reminderEnabled,
      'reminder_time': reminderTime?.wireValue,
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
      productName: map['product_name'] as String?,
      dosage: map['dosage'] as String?,
      // Off unless it was turned on. PM decision: a preventive record is
      // usually one dose in a routine the owner already tracks, and a
      // notification for every due date found was more than they asked for.
      reminderEnabled: map['reminder_enabled'] as bool? ?? false,
      reminderTime: ReminderTime.tryParse(map['reminder_time']),
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
    productName,
    dosage,
    reminderEnabled,
    reminderTime,
    visitId,
    hospitalName,
    nextDueDate,
    certificateFile,
    ocrExtractedData,
    ocrConfidence,
  ];
}
