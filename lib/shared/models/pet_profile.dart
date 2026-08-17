import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Spec 1.3 defines sex as part of "各種" without an explicit enum. We model
/// it as male/female since that's what the registration screen (1.2) implies
/// ("性別"). Neutering status is tracked separately via [neutered].
enum PetSex {
  male,
  female;

  String get wireName => name;

  static PetSex fromWireName(String value) {
    return PetSex.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => PetSex.male,
    );
  }
}

/// Mirrors spec section 1.3's pet fields. The spec's requirement column reads
/// "○（体重除く任意）" against the merged row
/// "pet_name / breed / birthday / sex / neutered", which we read as: every
/// field in that row is required, and weight is the one exception that is
/// optional (it can be filled in later from the weight-record feature in
/// section 3). See docs/dog_health_app_spec.md section 1.3.
class PetProfile extends Equatable {
  const PetProfile({
    required this.petId,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.birthday,
    required this.sex,
    required this.neutered,
    this.weightKg,
    this.neckGirthCm,
    this.chestGirthCm,
    this.backLengthCm,
    this.photoUrl,
    this.iconPhotoUrl,
    this.iconAlignmentX = 0.0,
    this.iconAlignmentY = 0.0,
    this.iconZoom = 1.0,
    this.backgroundAlignmentX = 0.0,
    this.backgroundAlignmentY = 0.0,
    this.backgroundZoom = 1.0,
  });

  final String petId;
  final String ownerId;
  final String name;
  final String breed;
  final DateTime birthday;
  final PetSex sex;
  final bool neutered;
  final double? weightKg;

  /// The three measurements dog clothing and harnesses are sized by (PM
  /// request: 首まわり・胴まわり・着丈). All optional -- an owner who never
  /// buys their dog a coat never needs them, and a half-filled set is
  /// still worth keeping.
  ///
  /// Stored in centimetres regardless of what the field displayed, the same
  /// way [weightKg] is stored in kilograms. English-language sizing charts
  /// are given in inches, so the input converts; the stored number must not.
  ///
  /// The English names are the ones the trade uses, so a chart can be read
  /// straight across: 首まわり = neck girth, 胴まわり = chest girth (the
  /// ribcage just behind the front legs, *not* body length), 着丈 = back
  /// length (base of neck to base of tail).
  final double? neckGirthCm;
  final double? chestGirthCm;
  final double? backLengthCm;

  /// Download URL for the pet's full-bleed background photo (Home screen),
  /// or null if none has been uploaded yet. Added after the initial spec
  /// 1.3 field set -- nullable and absent-safe so existing Firestore docs
  /// without this field still parse via [fromMap].
  final String? photoUrl;

  /// Download URL for the pet's small icon/avatar (settings list, pet
  /// switcher), independent of [photoUrl] (PM request: "愛犬アイコンと背景は
  /// 別々の画像を設定できるようにしたい"). Falls back to [photoUrl] at the
  /// call site when null, so existing pets with only a background photo
  /// still show *something* as their icon rather than a blank avatar.
  final String? iconPhotoUrl;

  /// Where within [iconPhotoUrl] the icon crop is centered, each in
  /// [-1.0, 1.0] (same convention as [Alignment]: 0 is centered, -1/+1 are
  /// the left-top/right-bottom edges). Lets the owner reposition an
  /// off-center photo instead of always cropping dead-center (PM request:
  /// "出力するアイコンについて表示位置...を設定できるようにしたい").
  final double iconAlignmentX;
  final double iconAlignmentY;

  /// Zoom factor applied to [iconPhotoUrl] before cropping to the icon's
  /// circular frame, >= 1.0 (PM request: same as above, "...サイズを設定
  /// できるように").
  final double iconZoom;

  /// The same framing triple as the icon's, for [photoUrl] on the Home
  /// screen. Separate fields rather than shared ones because the two photos
  /// are cropped to completely different shapes -- a circle and the
  /// full-bleed Home background -- so a framing that suits one is wrong for
  /// the other (PM request: adjust the background by pinching too).
  final double backgroundAlignmentX;
  final double backgroundAlignmentY;
  final double backgroundZoom;

  PetProfile copyWith({
    String? name,
    String? breed,
    DateTime? birthday,
    PetSex? sex,
    bool? neutered,
    double? weightKg,
    double? neckGirthCm,
    double? chestGirthCm,
    double? backLengthCm,
    String? photoUrl,
    String? iconPhotoUrl,
    double? iconAlignmentX,
    double? iconAlignmentY,
    double? iconZoom,
    double? backgroundAlignmentX,
    double? backgroundAlignmentY,
    double? backgroundZoom,
    bool clearPhotoUrl = false,
    bool clearIconPhotoUrl = false,
  }) {
    return PetProfile(
      petId: petId,
      ownerId: ownerId,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      birthday: birthday ?? this.birthday,
      sex: sex ?? this.sex,
      neutered: neutered ?? this.neutered,
      weightKg: weightKg ?? this.weightKg,
      neckGirthCm: neckGirthCm ?? this.neckGirthCm,
      chestGirthCm: chestGirthCm ?? this.chestGirthCm,
      backLengthCm: backLengthCm ?? this.backLengthCm,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      iconPhotoUrl: clearIconPhotoUrl
          ? null
          : (iconPhotoUrl ?? this.iconPhotoUrl),
      iconAlignmentX: iconAlignmentX ?? this.iconAlignmentX,
      iconAlignmentY: iconAlignmentY ?? this.iconAlignmentY,
      iconZoom: iconZoom ?? this.iconZoom,
      backgroundAlignmentX: backgroundAlignmentX ?? this.backgroundAlignmentX,
      backgroundAlignmentY: backgroundAlignmentY ?? this.backgroundAlignmentY,
      backgroundZoom: backgroundZoom ?? this.backgroundZoom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pet_id': petId,
      'owner_id': ownerId,
      'pet_name': name,
      'breed': breed,
      'birthday': Timestamp.fromDate(birthday),
      'sex': sex.wireName,
      'neutered': neutered,
      'weight_kg': weightKg,
      'neck_girth_cm': neckGirthCm,
      'chest_girth_cm': chestGirthCm,
      'back_length_cm': backLengthCm,
      'photo_url': photoUrl,
      'icon_photo_url': iconPhotoUrl,
      'icon_alignment_x': iconAlignmentX,
      'icon_alignment_y': iconAlignmentY,
      'icon_zoom': iconZoom,
      'background_alignment_x': backgroundAlignmentX,
      'background_alignment_y': backgroundAlignmentY,
      'background_zoom': backgroundZoom,
    };
  }

  factory PetProfile.fromMap(Map<String, dynamic> map) {
    final rawBirthday = map['birthday'];
    final birthday = rawBirthday is Timestamp
        ? rawBirthday.toDate()
        : DateTime.parse(rawBirthday as String);
    return PetProfile(
      petId: map['pet_id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['pet_name'] as String,
      breed: map['breed'] as String,
      birthday: birthday,
      sex: PetSex.fromWireName(map['sex'] as String? ?? 'male'),
      neutered: map['neutered'] as bool? ?? false,
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      neckGirthCm: (map['neck_girth_cm'] as num?)?.toDouble(),
      chestGirthCm: (map['chest_girth_cm'] as num?)?.toDouble(),
      backLengthCm: (map['back_length_cm'] as num?)?.toDouble(),
      photoUrl: map['photo_url'] as String?,
      iconPhotoUrl: map['icon_photo_url'] as String?,
      iconAlignmentX: (map['icon_alignment_x'] as num?)?.toDouble() ?? 0.0,
      iconAlignmentY: (map['icon_alignment_y'] as num?)?.toDouble() ?? 0.0,
      iconZoom: (map['icon_zoom'] as num?)?.toDouble() ?? 1.0,
      backgroundAlignmentX:
          (map['background_alignment_x'] as num?)?.toDouble() ?? 0.0,
      backgroundAlignmentY:
          (map['background_alignment_y'] as num?)?.toDouble() ?? 0.0,
      backgroundZoom: (map['background_zoom'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  List<Object?> get props => [
    petId,
    ownerId,
    name,
    breed,
    birthday,
    sex,
    neutered,
    weightKg,
    neckGirthCm,
    chestGirthCm,
    backLengthCm,
    photoUrl,
    iconPhotoUrl,
    iconAlignmentX,
    iconAlignmentY,
    iconZoom,
    backgroundAlignmentX,
    backgroundAlignmentY,
    backgroundZoom,
  ];
}
