import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// spec 4.3: type enum(urine, stool).
enum ToiletType {
  urine,
  stool;

  String get wireName => name;

  static ToiletType fromWireName(String value) {
    return ToiletType.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => ToiletType.urine,
    );
  }
}

/// spec 4.2: "便の状態選択（硬さ：正常／軟便／下痢／硬い...）".
enum StoolHardness {
  normal,
  soft,
  diarrhea,
  hard;

  String get wireName => name;

  static StoolHardness fromWireName(String value) {
    return StoolHardness.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => StoolHardness.normal,
    );
  }
}

/// spec 4.2: "...色：正常／血便疑い／白っぽい 等)".
enum StoolColor {
  normal,
  bloodSuspected,
  pale;

  String get wireName => name;

  static StoolColor fromWireName(String value) {
    return StoolColor.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => StoolColor.normal,
    );
  }
}

/// The spec's data table (4.3) lists `stool_condition` as a single `enum`
/// column, but the screen requirements (4.2) describe two independent
/// dimensions (hardness and color) that combine, e.g. "軟便 + 血便疑い" is a
/// valid combination. We model it as a small value object with both axes
/// rather than a single flattened enum, and store it as a nested map in
/// Firestore under the `stool_condition` field so the wire shape still
/// matches a single "stool_condition" column at the top level.
class StoolCondition extends Equatable {
  const StoolCondition({required this.hardness, required this.color});

  final StoolHardness hardness;
  final StoolColor color;

  Map<String, dynamic> toMap() {
    return {'hardness': hardness.wireName, 'color': color.wireName};
  }

  factory StoolCondition.fromMap(Map<String, dynamic> map) {
    return StoolCondition(
      hardness: StoolHardness.fromWireName(map['hardness'] as String? ?? 'normal'),
      color: StoolColor.fromWireName(map['color'] as String? ?? 'normal'),
    );
  }

  @override
  List<Object?> get props => [hardness, color];
}

/// Firestore model for spec section 4.3's toilet record. Field names below
/// (`toilet_id`, `pet_id`, `recorded_at`, `type`, `stool_condition`, `photo`)
/// mirror the spec table exactly. `stool_condition` is required when
/// `type == ToiletType.stool` and absent for `ToiletType.urine` (enforced at
/// the repository/form layer, not in this plain data class).
class ToiletRecord extends Equatable {
  const ToiletRecord({
    required this.toiletId,
    required this.petId,
    required this.recordedAt,
    required this.type,
    this.stoolCondition,
    this.photo,
  });

  final String toiletId;
  final String petId;
  final DateTime recordedAt;
  final ToiletType type;
  final StoolCondition? stoolCondition;
  final String? photo;

  ToiletRecord copyWith({
    DateTime? recordedAt,
    ToiletType? type,
    StoolCondition? stoolCondition,
    String? photo,
    bool clearStoolCondition = false,
    bool clearPhoto = false,
  }) {
    return ToiletRecord(
      toiletId: toiletId,
      petId: petId,
      recordedAt: recordedAt ?? this.recordedAt,
      type: type ?? this.type,
      stoolCondition: clearStoolCondition ? null : (stoolCondition ?? this.stoolCondition),
      photo: clearPhoto ? null : (photo ?? this.photo),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toilet_id': toiletId,
      'pet_id': petId,
      'recorded_at': Timestamp.fromDate(recordedAt),
      'type': type.wireName,
      'stool_condition': stoolCondition?.toMap(),
      'photo': photo,
    };
  }

  factory ToiletRecord.fromMap(Map<String, dynamic> map) {
    final rawRecordedAt = map['recorded_at'];
    final recordedAt = rawRecordedAt is Timestamp
        ? rawRecordedAt.toDate()
        : DateTime.parse(rawRecordedAt as String);
    final rawStoolCondition = map['stool_condition'] as Map<String, dynamic>?;
    return ToiletRecord(
      toiletId: map['toilet_id'] as String,
      petId: map['pet_id'] as String,
      recordedAt: recordedAt,
      type: ToiletType.fromWireName(map['type'] as String? ?? 'urine'),
      stoolCondition: rawStoolCondition != null ? StoolCondition.fromMap(rawStoolCondition) : null,
      photo: map['photo'] as String?,
    );
  }

  @override
  List<Object?> get props => [toiletId, petId, recordedAt, type, stoolCondition, photo];
}
