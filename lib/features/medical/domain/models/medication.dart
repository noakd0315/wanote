import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A time of day for a reminder.
///
/// Hour and minute rather than a `TimeOfDay` so the medical models keep no
/// Flutter dependency and stay trivially serializable. Written to Firestore
/// as "HH:mm", which is readable in the console and sorts correctly as a
/// string.
class ReminderTime extends Equatable implements Comparable<ReminderTime> {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  String get wireValue =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? tryParse(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return ReminderTime(hour, minute);
  }

  @override
  int compareTo(ReminderTime other) =>
      (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  List<Object?> get props => [hour, minute];
}

/// Mirrors spec section 5.2 (薬の記録). [endDate] is nullable to mean
/// "ongoing" (継続中扱い) per the spec's備考.
///
/// [reminderTimes] is a list because a course is often several doses a day
/// -- morning and evening, or with each meal (PM request). It replaces a
/// single hour/minute pair, which could only ever describe a once-daily
/// medicine.
class Medication extends Equatable {
  const Medication({
    required this.medicationId,
    required this.petId,
    required this.name,
    required this.startDate,
    required this.reminderEnabled,
    this.dosage,
    this.endDate,
    this.reminderTimes = const [],
  }) : assert(
         !reminderEnabled || reminderTimes.length > 0,
         'at least one reminder time is required when reminder_enabled is true (spec 5.2)',
       );

  final String medicationId;
  final String petId;
  final String name;
  final String? dosage;
  final DateTime startDate;

  /// Null means "continuing" (継続中) per spec 5.2.
  final DateTime? endDate;
  final bool reminderEnabled;

  /// Every time of day this medicine is due. Empty when reminders are off.
  final List<ReminderTime> reminderTimes;

  /// Whether the course is still running on [now].
  ///
  /// An end date in the future means the course is still on: the owner knew
  /// when it would finish and said so in advance. Treating any end date as
  /// "finished" marked a medicine as over the moment its last day was typed
  /// in (PM report, 2026-08-21).
  bool isOngoingAt(DateTime now) {
    final end = endDate;
    if (end == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(end.year, end.month, end.day).isBefore(today);
  }

  /// Whether the course has no end date at all.
  ///
  /// This is the form's "継続中（終了日未定）" switch, not "is it running
  /// today" -- see [isOngoingAt] for that.
  bool get hasNoEndDate => endDate == null;

  Medication copyWith({
    String? name,
    String? dosage,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? reminderEnabled,
    List<ReminderTime>? reminderTimes,
  }) {
    return Medication(
      medicationId: medicationId,
      petId: petId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
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
      'reminder_times': [for (final time in reminderTimes) time.wireValue],
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
      reminderTimes: _readReminderTimes(map),
    );
  }

  /// Reads the list, falling back to the single hour/minute a document
  /// written before this change would have. Records already saved on a
  /// phone must keep their reminder rather than quietly losing it.
  static List<ReminderTime> _readReminderTimes(Map<String, dynamic> map) {
    final raw = map['reminder_times'];
    if (raw is List) {
      final times = <ReminderTime>[];
      for (final value in raw) {
        final time = ReminderTime.tryParse(value);
        if (time != null) times.add(time);
      }
      if (times.isNotEmpty) return (times..sort());
    }
    final hour = (map['reminder_hour'] as num?)?.toInt();
    final minute = (map['reminder_minute'] as num?)?.toInt();
    if (hour == null || minute == null) return const [];
    return [ReminderTime(hour, minute)];
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
    reminderTimes,
  ];
}
