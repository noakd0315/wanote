import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Spec 5.3: 混合ワクチン／狂犬病ワクチンは vaccine 内のサブ種別として扱う,
/// so we don't model those as separate top-level types.
///
/// Heartworm and flea/tick prevention were originally two separate types,
/// but combined flea+tick+heartworm products exist as a single medication
/// (PM report: "ノミ・ダニ・フィラリアが１つの薬になっていることがある") --
/// splitting them didn't match how these are actually prescribed/sold, so
/// they're merged into one non-vaccine [medication] type.
enum PreventionType {
  vaccine,
  medication;

  String get wireName => switch (this) {
    PreventionType.vaccine => 'vaccine',
    PreventionType.medication => 'medication',
  };

  static PreventionType fromWireName(String value) {
    // 'heartworm'/'flea_tick' are legacy wire values from before the merge
    // above -- mapped forward so existing Firestore docs keep working.
    if (value == 'heartworm' || value == 'flea_tick') {
      return PreventionType.medication;
    }
    return PreventionType.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => PreventionType.vaccine,
    );
  }
}

/// Spec 5.3: ワクチンは基本 single（都度登録）、フィラリア・ノミダニは monthly
/// が主流. `custom` covers anything else (e.g. a vet-prescribed non-standard
/// interval) and requires [PreventionProgram.intervalDays].
enum ScheduleType {
  single,
  monthly,
  annual,
  custom;

  String get wireName => name;

  static ScheduleType fromWireName(String value) {
    return ScheduleType.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => ScheduleType.single,
    );
  }
}

/// Prevention program (何をどの頻度で行うかの設定) per spec 5.3.
class PreventionProgram extends Equatable {
  const PreventionProgram({
    required this.programId,
    required this.petId,
    required this.type,
    required this.productName,
    required this.scheduleType,
    required this.startDate,
    required this.active,
    this.intervalDays,
  }) : assert(
         scheduleType != ScheduleType.custom || intervalDays != null,
         'interval_days is required when schedule_type is custom (spec 5.3)',
       );

  final String programId;
  final String petId;
  final PreventionType type;
  final String productName;
  final ScheduleType scheduleType;

  /// Required iff [scheduleType] == [ScheduleType.custom].
  final int? intervalDays;
  final DateTime startDate;
  final bool active;

  PreventionProgram copyWith({
    PreventionType? type,
    String? productName,
    ScheduleType? scheduleType,
    int? intervalDays,
    bool clearIntervalDays = false,
    DateTime? startDate,
    bool? active,
  }) {
    return PreventionProgram(
      programId: programId,
      petId: petId,
      type: type ?? this.type,
      productName: productName ?? this.productName,
      scheduleType: scheduleType ?? this.scheduleType,
      intervalDays: clearIntervalDays
          ? null
          : (intervalDays ?? this.intervalDays),
      startDate: startDate ?? this.startDate,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'program_id': programId,
      'pet_id': petId,
      'type': type.wireName,
      'product_name': productName,
      'schedule_type': scheduleType.wireName,
      'interval_days': intervalDays,
      'start_date': Timestamp.fromDate(startDate),
      'active': active,
    };
  }

  factory PreventionProgram.fromMap(Map<String, dynamic> map) {
    final rawStart = map['start_date'];
    final startDate = rawStart is Timestamp
        ? rawStart.toDate()
        : DateTime.parse(rawStart as String);
    return PreventionProgram(
      programId: map['program_id'] as String,
      petId: map['pet_id'] as String,
      type: PreventionType.fromWireName(map['type'] as String),
      productName: map['product_name'] as String,
      scheduleType: ScheduleType.fromWireName(map['schedule_type'] as String),
      intervalDays: (map['interval_days'] as num?)?.toInt(),
      startDate: startDate,
      active: map['active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
    programId,
    petId,
    type,
    productName,
    scheduleType,
    intervalDays,
    startDate,
    active,
  ];
}
