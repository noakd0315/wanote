import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/models/pet_profile.dart';

void main() {
  group('PetProfile.photoUrl', () {
    final birthday = DateTime(2020, 1, 1);

    PetProfile buildPet({String? photoUrl}) => PetProfile(
      petId: 'pet-1',
      ownerId: 'owner-1',
      name: 'Pochi',
      breed: 'Shiba',
      birthday: birthday,
      sex: PetSex.male,
      neutered: false,
      weightKg: 8.5,
      photoUrl: photoUrl,
    );

    test('round-trips through toMap/fromMap when set', () {
      final pet = buildPet(photoUrl: 'https://example.com/photo.jpg');

      final map = pet.toMap();
      expect(map['photo_url'], 'https://example.com/photo.jpg');

      final restored = PetProfile.fromMap(map);
      expect(restored.photoUrl, 'https://example.com/photo.jpg');
      expect(restored, pet);
    });

    test('round-trips as null when absent', () {
      final pet = buildPet();

      final map = pet.toMap();
      expect(map['photo_url'], isNull);

      final restored = PetProfile.fromMap(map);
      expect(restored.photoUrl, isNull);
      expect(restored, pet);
    });

    test(
      'fromMap defaults photoUrl to null for legacy docs missing the field '
      '(backward compatibility)',
      () {
        // Simulates a pre-existing Firestore document written before
        // photoUrl existed -- no 'photo_url' key at all.
        final legacyMap = <String, dynamic>{
          'pet_id': 'pet-1',
          'owner_id': 'owner-1',
          'pet_name': 'Pochi',
          'breed': 'Shiba',
          'birthday': Timestamp.fromDate(birthday),
          'sex': 'male',
          'neutered': false,
          'weight_kg': 8.5,
        };

        final restored = PetProfile.fromMap(legacyMap);

        expect(restored.photoUrl, isNull);
      },
    );

    test('copyWith preserves photoUrl when not overridden', () {
      final pet = buildPet(photoUrl: 'https://example.com/photo.jpg');
      final updated = pet.copyWith(name: 'Pochi-chan');

      expect(updated.photoUrl, 'https://example.com/photo.jpg');
      expect(updated.name, 'Pochi-chan');
    });

    test('copyWith overrides photoUrl when provided', () {
      final pet = buildPet(photoUrl: 'https://example.com/old.jpg');
      final updated = pet.copyWith(photoUrl: 'https://example.com/new.jpg');

      expect(updated.photoUrl, 'https://example.com/new.jpg');
    });
  });
}
