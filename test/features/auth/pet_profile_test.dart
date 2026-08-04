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

    test('fromMap defaults photoUrl to null for legacy docs missing the field '
        '(backward compatibility)', () {
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
    });

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

    test(
      'copyWith(clearPhotoUrl: true) nulls it out even with no other args',
      () {
        final pet = buildPet(photoUrl: 'https://example.com/old.jpg');
        final updated = pet.copyWith(clearPhotoUrl: true);

        expect(updated.photoUrl, isNull);
      },
    );
  });

  group('PetProfile icon fields', () {
    final birthday = DateTime(2020, 1, 1);

    PetProfile buildPet({
      String? iconPhotoUrl,
      double iconAlignmentX = 0.0,
      double iconAlignmentY = 0.0,
      double iconZoom = 1.0,
    }) => PetProfile(
      petId: 'pet-1',
      ownerId: 'owner-1',
      name: 'Pochi',
      breed: 'Shiba',
      birthday: birthday,
      sex: PetSex.male,
      neutered: false,
      iconPhotoUrl: iconPhotoUrl,
      iconAlignmentX: iconAlignmentX,
      iconAlignmentY: iconAlignmentY,
      iconZoom: iconZoom,
    );

    test('iconAlignment/iconZoom default to centered/no-zoom', () {
      final pet = buildPet();

      expect(pet.iconAlignmentX, 0.0);
      expect(pet.iconAlignmentY, 0.0);
      expect(pet.iconZoom, 1.0);
    });

    test('round-trips icon fields through toMap/fromMap when set', () {
      final pet = buildPet(
        iconPhotoUrl: 'https://example.com/icon.jpg',
        iconAlignmentX: 0.4,
        iconAlignmentY: -0.2,
        iconZoom: 1.8,
      );

      final map = pet.toMap();
      expect(map['icon_photo_url'], 'https://example.com/icon.jpg');
      expect(map['icon_alignment_x'], 0.4);
      expect(map['icon_alignment_y'], -0.2);
      expect(map['icon_zoom'], 1.8);

      final restored = PetProfile.fromMap(map);
      expect(restored, pet);
    });

    test('fromMap defaults icon fields for legacy docs missing them '
        '(backward compatibility)', () {
      final legacyMap = <String, dynamic>{
        'pet_id': 'pet-1',
        'owner_id': 'owner-1',
        'pet_name': 'Pochi',
        'breed': 'Shiba',
        'birthday': Timestamp.fromDate(birthday),
        'sex': 'male',
        'neutered': false,
      };

      final restored = PetProfile.fromMap(legacyMap);

      expect(restored.iconPhotoUrl, isNull);
      expect(restored.iconAlignmentX, 0.0);
      expect(restored.iconAlignmentY, 0.0);
      expect(restored.iconZoom, 1.0);
    });

    test(
      'copyWith(clearIconPhotoUrl: true) nulls it out independently of photoUrl',
      () {
        final pet = PetProfile(
          petId: 'pet-1',
          ownerId: 'owner-1',
          name: 'Pochi',
          breed: 'Shiba',
          birthday: birthday,
          sex: PetSex.male,
          neutered: false,
          photoUrl: 'https://example.com/bg.jpg',
          iconPhotoUrl: 'https://example.com/icon.jpg',
        );
        final updated = pet.copyWith(clearIconPhotoUrl: true);

        expect(updated.iconPhotoUrl, isNull);
        expect(updated.photoUrl, 'https://example.com/bg.jpg');
      },
    );
  });
}
