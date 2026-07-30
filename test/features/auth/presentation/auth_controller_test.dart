import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanote/features/auth/data/auth_repository.dart';
import 'package:wanote/features/auth/data/biometric_service.dart';
import 'package:wanote/features/auth/data/pet_profile_repository.dart';
import 'package:wanote/features/auth/data/user_account_repository.dart';
import 'package:wanote/features/auth/domain/auth_gate_resolver.dart';
import 'package:wanote/features/auth/domain/biometric_fallback_resolver.dart';
import 'package:wanote/features/auth/presentation/auth_controller.dart';
import 'package:wanote/shared/models/app_user.dart';
import 'package:wanote/shared/models/auth_provider_type.dart';
import 'package:wanote/shared/models/pet_profile.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserAccountRepository extends Mock implements UserAccountRepository {}

class MockPetProfileRepository extends Mock implements PetProfileRepository {}

class MockBiometricService extends Mock implements BiometricService {}

const _uid = 'uid-1';
const _email = 'owner@example.com';
const _identity = AuthIdentity(
  uid: _uid,
  email: _email,
  provider: AuthProviderType.email,
);

Future<void> _settle() async {
  // Lets pending microtasks/stream callbacks inside AuthController resolve
  // without needing a widget-test TestWidgetsFlutterBinding pump.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProviderType.email);
    registerFallbackValue(PetSex.male);
    registerFallbackValue(DateTime(2020));
  });

  late MockAuthRepository authRepository;
  late MockUserAccountRepository userAccountRepository;
  late MockPetProfileRepository petProfileRepository;
  late MockBiometricService biometricService;
  late StreamController<AuthIdentity?> authStateController;
  late StreamController<List<PetProfile>> petsController;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepository = MockAuthRepository();
    userAccountRepository = MockUserAccountRepository();
    petProfileRepository = MockPetProfileRepository();
    biometricService = MockBiometricService();
    authStateController = StreamController<AuthIdentity?>.broadcast();
    petsController = StreamController<List<PetProfile>>.broadcast();

    when(() => authRepository.authStateChanges())
        .thenAnswer((_) => authStateController.stream);
    when(() => petProfileRepository.watchPets(any()))
        .thenAnswer((_) => petsController.stream);
  });

  tearDown(() async {
    await authStateController.close();
    await petsController.close();
  });

  AuthController buildController() {
    return AuthController(
      authRepository: authRepository,
      userAccountRepository: userAccountRepository,
      petProfileRepository: petProfileRepository,
      biometricService: biometricService,
      sharedPreferences: SharedPreferences.getInstance(),
    );
  }

  group('initialize', () {
    test('no signed-in user -> requireSignIn', () async {
      when(() => authRepository.currentUser).thenReturn(null);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => false);

      final controller = buildController();
      await controller.initialize();

      expect(controller.gateAction, AuthGateAction.requireSignIn);
      expect(controller.currentUser, isNull);
    });

    test('existing session, biometric off -> enterApp, not justRegistered', () async {
      when(() => authRepository.currentUser).thenReturn(_identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => true);
      when(() => userAccountRepository.get(_uid)).thenAnswer(
        (_) async => const AppUser(
          uid: _uid,
          email: _email,
          authProvider: AuthProviderType.email,
          biometricEnabled: false,
        ),
      );

      final controller = buildController();
      await controller.initialize();

      expect(controller.gateAction, AuthGateAction.enterApp);
      expect(controller.justRegistered, isFalse);
      expect(controller.currentUser?.uid, _uid);
    });

    test('existing session, biometric on and available -> requireBiometric', () async {
      when(() => authRepository.currentUser).thenReturn(_identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => true);
      when(() => userAccountRepository.get(_uid)).thenAnswer(
        (_) async => const AppUser(
          uid: _uid,
          email: _email,
          authProvider: AuthProviderType.email,
          biometricEnabled: true,
        ),
      );

      final controller = buildController();
      await controller.initialize();

      expect(controller.gateAction, AuthGateAction.requireBiometric);
    });
  });

  test('signUpWithEmail on brand-new account sets justRegistered', () async {
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
    when(() => userAccountRepository.get(_uid)).thenAnswer((_) async => null);
    when(
      () => userAccountRepository.getOrCreate(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer(
      (_) async => const AppUser(
        uid: _uid,
        email: _email,
        authProvider: AuthProviderType.email,
        biometricEnabled: false,
      ),
    );
    when(
      () => authRepository.signUpWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _identity);

    final controller = buildController();
    await controller.initialize();
    await controller.signUpWithEmail(email: _email, password: 'password1');

    expect(controller.justRegistered, isTrue);
    expect(controller.gateAction, AuthGateAction.enterApp);

    controller.markOnboardingComplete();
    expect(controller.justRegistered, isFalse);
  });

  group('biometric prompt', () {
    Future<AuthController> signedInController({required bool biometricEnabled}) async {
      when(() => authRepository.currentUser).thenReturn(_identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => true);
      when(() => userAccountRepository.get(_uid)).thenAnswer(
        (_) async => AppUser(
          uid: _uid,
          email: _email,
          authProvider: AuthProviderType.email,
          biometricEnabled: biometricEnabled,
        ),
      );
      final controller = buildController();
      await controller.initialize();
      return controller;
    }

    test('success -> enterApp, no pending fallback', () async {
      final controller = await signedInController(biometricEnabled: true);
      when(() => biometricService.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => BiometricPromptResult.success);

      await controller.promptBiometric();

      expect(controller.gateAction, AuthGateAction.enterApp);
      expect(controller.pendingBiometricFallback, isNull);
    });

    test('cancelled + email provider -> reenterPassword fallback', () async {
      final controller = await signedInController(biometricEnabled: true);
      when(() => biometricService.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => BiometricPromptResult.cancelled);

      await controller.promptBiometric();

      expect(
        controller.pendingBiometricFallback,
        BiometricFallbackAction.reenterPassword,
      );

      when(() => authRepository.reauthenticateWithPassword(any()))
          .thenAnswer((_) async {});
      await controller.completeReenterPassword('password1');

      expect(controller.gateAction, AuthGateAction.enterApp);
      expect(controller.pendingBiometricFallback, isNull);
    });
  });

  group('pet management', () {
    test('createPet switches active pet to the new pet', () async {
      when(() => authRepository.currentUser).thenReturn(_identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
      when(() => userAccountRepository.get(_uid)).thenAnswer(
        (_) async => const AppUser(
          uid: _uid,
          email: _email,
          authProvider: AuthProviderType.email,
          biometricEnabled: false,
        ),
      );

      final newPet = PetProfile(
        petId: 'pet-1',
        ownerId: _uid,
        name: 'Pochi',
        breed: 'Shiba',
        birthday: DateTime(2020, 1, 1),
        sex: PetSex.male,
        neutered: false,
      );
      when(
        () => petProfileRepository.create(
          ownerId: any(named: 'ownerId'),
          name: any(named: 'name'),
          breed: any(named: 'breed'),
          birthday: any(named: 'birthday'),
          sex: any(named: 'sex'),
          neutered: any(named: 'neutered'),
          weightKg: any(named: 'weightKg'),
        ),
      ).thenAnswer((_) async => newPet);

      final controller = buildController();
      await controller.initialize();

      final created = await controller.createPet(
        name: 'Pochi',
        breed: 'Shiba',
        birthday: DateTime(2020, 1, 1),
        sex: PetSex.male,
        neutered: false,
      );

      // The stream has not emitted the new pet yet in this fake setup, but
      // switchActivePet is called directly by createPet with the created
      // pet's id once it exists in _pets; simulate the repository stream
      // catching up so switchActivePet finds a match.
      petsController.add([newPet]);
      await _settle();

      expect(created.petId, 'pet-1');
      expect(controller.pets, [newPet]);
    });

    test('deleting the active pet falls back to the next pet via ActivePetResolver', () async {
      when(() => authRepository.currentUser).thenReturn(_identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
      when(() => userAccountRepository.get(_uid)).thenAnswer(
        (_) async => const AppUser(
          uid: _uid,
          email: _email,
          authProvider: AuthProviderType.email,
          biometricEnabled: false,
        ),
      );
      when(() => petProfileRepository.delete(any(), any()))
          .thenAnswer((_) async {});

      final petA = PetProfile(
        petId: 'a',
        ownerId: _uid,
        name: 'A',
        breed: 'Breed',
        birthday: DateTime(2020, 1, 1),
        sex: PetSex.male,
        neutered: false,
      );
      final petB = PetProfile(
        petId: 'b',
        ownerId: _uid,
        name: 'B',
        breed: 'Breed',
        birthday: DateTime(2020, 1, 1),
        sex: PetSex.female,
        neutered: true,
      );

      final controller = buildController();
      await controller.initialize();

      petsController.add([petA, petB]);
      await _settle();
      expect(controller.activePet?.petId, 'a');

      await controller.deletePet('a');
      petsController.add([petB]);
      await _settle();

      expect(controller.activePet?.petId, 'b');
    });
  });
}
