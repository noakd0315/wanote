import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Mirrors spec section 5.2 (薬の記録). [endDate] is nullable to mean
/// "ongoing" (継続中扱い) per the spec's備考. When [reminderEnabled] is true
/// the spec requires a reminder time, modelled here as separate hour/minute
/// ints rather than a `TimeOfDay` so this model has no Flutter/material
/// dependency and stays trivially testable/serializable.
class Medication extends Equatable {
  const Medication({
    required this.medicationId,
    required this.petId,
    required this.name,
    required this.startDate,
    required this.reminderEnabled,
    this.dosage,
    this.endDate,
    this.reminderHour,
    this.reminderMinute,
  }) : assert(
         !reminderEnabled || (reminderHour != null && reminderMinute != null),
         'reminder_time is required when reminder_enabled is true (spec 5.2)',
       );

  final String medicationId;
  final String petId;
  final String name;
  final String? dosage;
  final DateTime startDate;

  /// Null means "continuing" (継続中) per spec 5.2.
  final DateTime? endDate;
  final bool reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;

  bool get isOngoing => endDate == null;

  Medication copyWith({
    String? name,
    String? dosage,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return Medication(
      medicationId: medicationId,
      petId: petId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medication_id': medicationId,
      'pet_id': petId,
      'name': name,
      'dosage': dosage,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': endDate == null ? null : Timestamp.fromDate(endDate!),
      'reminder_enabled': reminderEnabled,
      'reminder_hour': reminderHour,
      'reminder_minute': reminderMinute,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      medicationId: map['medication_id'] as String,
      petId: map['pet_id'] as String,
      name: map['name'] as String,
      dosage: map['dosage'] as String?,
      startDate: _readDate(map['start_date'])!,
      endDate: _readDate(map['end_date']),
      reminderEnabled: map['reminder_enabled'] as bool? ?? false,
      reminderHour: (map['reminder_hour'] as num?)?.toInt(),
      reminderMinute: (map['reminder_minute'] as num?)?.toInt(),
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
    medicationId,
    petId,
    name,
    dosage,
    startDate,
    endDate,
    reminderEnabled,
    reminderHour,
    reminderMinute,
  ];
}
