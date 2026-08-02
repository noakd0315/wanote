import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../../../shared/models/pet_profile.dart';
import 'photo_compressor.dart';

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

  /// Compresses [bytes] and uploads them to Firebase Storage as
  /// `users/{ownerId}/pets/{petId}/profile.jpg`, returning the download
  /// URL. Callers are responsible for persisting the URL onto the pet via
  /// [update] -- kept as two steps because a brand-new pet has no id until
  /// [create] returns, mirroring how certificate photos are uploaded in
  /// features/medical.
  Future<String> uploadPhoto({
    required String ownerId,
    required String petId,
    required Uint8List bytes,
  });
}

class FirestorePetProfileRepository implements PetProfileRepository {
  FirestorePetProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    PhotoCompressor? photoCompressor,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _photoCompressor =
           photoCompressor ?? const FlutterImagePhotoCompressor(),
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final PhotoCompressor _photoCompressor;
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

  @override
  Future<String> uploadPhoto({
    required String ownerId,
    required String petId,
    required Uint8List bytes,
  }) async {
    final compressed = await _photoCompressor.compress(bytes);
    final ref = _storage.ref('users/$ownerId/pets/$petId/profile.jpg');
    await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
