import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/models/pet_profile.dart';

/// PM request: frame the Home background photo by pinching, like the icon.
///
/// The framing is only useful if it survives the Firestore round trip, and
/// existing pets were saved before these fields existed -- a missing field
/// must read back as "unframed", not crash or come back null.
PetProfile _pet({double bgX = 0, double bgY = 0, double bgZoom = 1}) =>
    PetProfile(
      petId: 'pet-1',
      ownerId: 'owner-1',
      name: 'ポチ',
      breed: '柴犬',
      birthday: DateTime(2024, 1, 1),
      sex: PetSex.male,
      neutered: false,
      backgroundAlignmentX: bgX,
      backgroundAlignmentY: bgY,
      backgroundZoom: bgZoom,
    );

void main() {
  test('background framing survives a toMap/fromMap round trip', () {
    final pet = _pet(bgX: -0.4, bgY: 0.75, bgZoom: 2.5);
    final restored = PetProfile.fromMap(pet.toMap());

    expect(restored.backgroundAlignmentX, -0.4);
    expect(restored.backgroundAlignmentY, 0.75);
    expect(restored.backgroundZoom, 2.5);
  });

  test('a doc saved before these fields existed reads back as unframed', () {
    final map = _pet().toMap()
      ..remove('background_alignment_x')
      ..remove('background_alignment_y')
      ..remove('background_zoom');

    final restored = PetProfile.fromMap(map);

    expect(restored.backgroundAlignmentX, 0.0);
    expect(restored.backgroundAlignmentY, 0.0);
    expect(
      restored.backgroundZoom,
      1.0,
      reason: 'Zoom must default to 1, not 0 -- 0 would collapse the photo.',
    );
  });

  test('background and icon framing are stored independently', () {
    // The two crops are different shapes, so sharing one set of values would
    // make framing the icon silently re-frame the Home background.
    final pet = _pet(bgX: 1, bgY: 1, bgZoom: 3);
    expect(pet.iconAlignmentX, 0);
    expect(pet.iconAlignmentY, 0);
    expect(pet.iconZoom, 1);

    final reframedIcon = pet.copyWith(iconAlignmentX: -1, iconZoom: 2);
    expect(reframedIcon.backgroundAlignmentX, 1);
    expect(reframedIcon.backgroundZoom, 3);
  });
}
