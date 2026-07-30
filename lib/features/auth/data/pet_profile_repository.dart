import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../../../shared/models/pet_profile.dart';

/// CRUD + live list of pet profiles for one account. Backs the "multi-pet
/// household" requirement in spec 1.4 (複数ペット登録・切り替え).
abstract class PetProfileRepository {
  Stream<List<PetProfile>> watchPets(String ownerId);

  Future<PetProfile> create({
    required String ownerId,
    required String name,
    required String breed,
    required DateTime birthday,
    required PetSex sex,
    required bool neutered,
    double? weightKg,
  });

  Future<void> update(PetProfile pet);

  Future<void> delete(String ownerId, String petId);
}

class FirestorePetProfileRepository implements PetProfileRepository {
  FirestorePetProfileRepository({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  @override
  Stream<List<PetProfile>> watchPets(String ownerId) {
    return _firestore
        .collection(FirestorePaths.pets(ownerId))
        .orderBy('pet_name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => PetProfile.fromMap(d.data())).toList());
  }

  @override
  Future<PetProfile> create({
    required String ownerId,
    required String name,
    required String breed,
    required DateTime birthday,
    required PetSex sex,
    required bool neutered,
    double? weightKg,
  }) async {
    final pet = PetProfile(
      petId: _uuid.v4(),
      ownerId: ownerId,
      name: name,
      breed: breed,
      birthday: birthday,
      sex: sex,
      neutered: neutered,
      weightKg: weightKg,
    );
    await _firestore
        .doc(FirestorePaths.pet(ownerId, pet.petId))
        .set(pet.toMap());
    return pet;
  }

  @override
  Future<void> update(PetProfile pet) async {
    await _firestore
        .doc(FirestorePaths.pet(pet.ownerId, pet.petId))
        .set(pet.toMap());
  }

  @override
  Future<void> delete(String ownerId, String petId) async {
    await _firestore.doc(FirestorePaths.pet(ownerId, petId)).delete();
  }
}
