import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/auth/domain/active_pet_resolver.dart';

void main() {
  group('ActivePetResolver', () {
    const resolver = ActivePetResolver();

    test('empty pet list -> null (no active pet)', () {
      expect(
        resolver.resolve(petIds: const [], previousActiveId: null),
        isNull,
      );
      expect(
        resolver.resolve(petIds: const [], previousActiveId: 'ghost-id'),
        isNull,
      );
    });

    test('previous active id still present -> keep it', () {
      expect(
        resolver.resolve(
          petIds: const ['a', 'b', 'c'],
          previousActiveId: 'b',
        ),
        'b',
      );
    });

    test('previous active id removed -> fall back to first pet', () {
      expect(
        resolver.resolve(
          petIds: const ['a', 'b', 'c'],
          previousActiveId: 'removed-id',
        ),
        'a',
      );
    });

    test('initial load with no previous id -> first pet', () {
      expect(
        resolver.resolve(petIds: const ['only-pet'], previousActiveId: null),
        'only-pet',
      );
      expect(
        resolver.resolve(petIds: const ['first', 'second'], previousActiveId: null),
        'first',
      );
    });
  });
}
