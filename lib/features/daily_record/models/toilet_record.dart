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

/// Urine color shade (PM request: "排尿に色の濃淡を設定できるようにしたい") --
/// a rough proxy owners can judge at a glance without lab equipment. Darker
/// (濃い) urine can signal dehydration/concentration; noticeably paler
/// (薄い) than usual can signal overhydration. Kept to a 3-tier shade scale
/// per the PM's request, not a full color-abnormality list like
/// [StoolColor]'s blood-suspicion option.
enum UrineColor {
  pale,
  normal,
  dark;

  String get wireName => name;

  String get label => switch (this) {
    UrineColor.pale => '薄い（無色に近い）',
    UrineColor.normal => '正常（淡黄色）',
    UrineColor.dark => '濃い（濃縮尿）',
  };

  static UrineColor fromWireName(String value) {
    return UrineColor.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => UrineColor.normal,
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
      hardness: StoolHardness.fromWireName(
        map['hardness'] as String? ?? 'normal',
      ),
      color: StoolColor.fromWireName(map['color'] as String? ?? 'normal'),
    );
  }

  @override
  List<Object?> get props => [hardness, color];
}

/// Firestore model for spec section 4.3's toilet record. Field names below
/// (`toilet_id`, `pet_id`, `recorded_at`, `type`, `stool_condition`,
/// `urine_color`, `photo`) mirror the spec table plus the PM-requested
/// `urine_color` addition. `stool_condition` is required when
/// `type == ToiletType.stool` and `urine_color` only meaningful when
/// `type == ToiletType.urine` (each null/absent for the other type,
/// enforced at the repository/form layer, not in this plain data class).
class ToiletRecord extends Equatable {
  const ToiletRecord({
    required this.toiletId,
    required this.petId,
    required this.recordedAt,
    required this.type,
    this.stoolCondition,
    this.urineColor,
    this.photo,
  });

  final String toiletId;
  final String petId;
  final DateTime recordedAt;
  final ToiletType type;
  final StoolCondition? stoolCondition;
  final UrineColor? urineColor;
  final String? photo;

  ToiletRecord copyWith({
    DateTime? recordedAt,
    ToiletType? type,
    StoolCondition? stoolCondition,
    UrineColor? urineColor,
    String? photo,
    bool clearStoolCondition = false,
    bool clearUrineColor = false,
    bool clearPhoto = false,
  }) {
    return ToiletRecord(
      toiletId: toiletId,
      petId: petId,
      recordedAt: recordedAt ?? this.recordedAt,
      type: type ?? this.type,
      stoolCondition: clearStoolCondition
          ? null
          : (stoolCondition ?? this.stoolCondition),
      urineColor: clearUrineColor ? null : (urineColor ?? this.urineColor),
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
      'urine_color': urineColor?.wireName,
      'photo': photo,
    };
  }

  factory ToiletRecord.fromMap(Map<String, dynamic> map) {
    final rawRecordedAt = map['recorded_at'];
    final recordedAt = rawRecordedAt is Timestamp
        ? rawRecordedAt.toDate()
        : DateTime.parse(rawRecordedAt as String);
    final rawStoolCondition = map['stool_condition'] as Map<String, dynamic>?;
    final rawUrineColor = map['urine_color'] as String?;
    return ToiletRecord(
      toiletId: map['toilet_id'] as String,
      petId: map['pet_id'] as String,
      recordedAt: recordedAt,
      type: ToiletType.fromWireName(map['type'] as String? ?? 'urine'),
      stoolCondition: rawStoolCondition != null
          ? StoolCondition.fromMap(rawStoolCondition)
          : null,
      urineColor: rawUrineColor != null
          ? UrineColor.fromWireName(rawUrineColor)
          : null,
      photo: map['photo'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    toiletId,
    petId,
    recordedAt,
    type,
    stoolCondition,
    urineColor,
    photo,
  ];
}
