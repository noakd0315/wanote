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
    this.photoUrl,
  });

  final String petId;
  final String ownerId;
  final String name;
  final String breed;
  final DateTime birthday;
  final PetSex sex;
  final bool neutered;
  final double? weightKg;

  /// Download URL for the pet's profile photo (Firebase Storage), or null
  /// if none has been uploaded yet. Added after the initial spec 1.3 field
  /// set -- nullable and absent-safe so existing Firestore docs without
  /// this field still parse via [fromMap].
  final String? photoUrl;

  PetProfile copyWith({
    String? name,
    String? breed,
    DateTime? birthday,
    PetSex? sex,
    bool? neutered,
    double? weightKg,
    String? photoUrl,
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
      photoUrl: photoUrl ?? this.photoUrl,
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
      'photo_url': photoUrl,
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
      photoUrl: map['photo_url'] as String?,
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
    photoUrl,
  ];
}
