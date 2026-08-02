import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/app/home_screen.dart';

void main() {
  group('shouldShowPetPhotoBackground', () {
    test('is false when photoUrl is null', () {
      expect(shouldShowPetPhotoBackground(null), isFalse);
    });

    test('is false when photoUrl is empty or blank', () {
      expect(shouldShowPetPhotoBackground(''), isFalse);
      expect(shouldShowPetPhotoBackground('   '), isFalse);
    });

    test('is true when photoUrl is a non-blank string', () {
      expect(
        shouldShowPetPhotoBackground('https://example.com/photo.jpg'),
        isTrue,
      );
    });
  });
}
