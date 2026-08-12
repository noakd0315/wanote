import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanote/features/auth/data/account_deletion_service.dart';
import 'package:wanote/features/auth/data/auth_prefs_keys.dart';
import 'package:wanote/features/auth/data/auth_repository.dart';
import 'package:wanote/features/auth/data/biometric_service.dart';
import 'package:wanote/features/auth/data/pet_profile_repository.dart';
import 'package:wanote/features/auth/data/user_account_repository.dart';
import 'package:wanote/shared/models/app_user.dart';
import 'package:wanote/shared/models/auth_provider_type.dart';
import 'package:wanote/shared/models/pet_profile.dart';
import 'package:wanote/features/auth/presentation/auth_controller.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserAccountRepository extends Mock implements UserAccountRepository {}

class MockPetProfileRepository extends Mock implements PetProfileRepository {}

class MockBiometricService extends Mock implements BiometricService {}

class MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

/// Account deletion as the controller drives it.
///
/// Two things are being pinned. Reauthentication happens *before* anything is
/// erased -- Firebase requires a fresh credential to delete a user, but more
/// importantly an unattended unlocked phone should not be enough to wipe
/// someone's records. And the device's own leftovers are cleared only after
/// the account is actually gone, so a failed attempt doesn't sign the user
/// out of an account that still exists.
void main() {
  const uid = 'uid-1';
  const email = 'owner@example.com';

  late MockAuthRepository authRepository;
  late MockUserAccountRepository userAccountRepository;
  late MockPetProfileRepository petProfileRepository;
  late MockBiometricService biometricService;
  late MockAccountDeletionService deletionService;
  late StreamController<AuthIdentity?> authStateController;

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AuthPrefsKeys.lastActivePetId: 'pet-1',
      '${AuthPrefsKeys.localSessionIdPrefix}$uid': 'session-1',
      '${AuthPrefsKeys.lastAuthenticatedAtPrefix}$uid': DateTime.now()
          .toIso8601String(),
      AuthPrefsKeys.rememberedEmail: email,
      AuthPrefsKeys.pendingReferralCode: 'REF-ABC',
      // Not the auth feature's, and not account-specific: a UI preference
      // that has no business being wiped by an account deletion.
      'weight_chart.show_table': true,
    });

    authRepository = MockAuthRepository();
    userAccountRepository = MockUserAccountRepository();
    petProfileRepository = MockPetProfileRepository();
    biometricService = MockBiometricService();
    deletionService = MockAccountDeletionService();
    authStateController = StreamController<AuthIdentity?>.broadcast();

    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => authStateController.stream);
    when(
      () => petProfileRepository.watchPets(any()),
    ).thenAnswer((_) => const Stream<List<PetProfile>>.empty());
    when(
      () => userAccountRepository.watchActiveSessionId(any()),
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
    when(
      () => authRepository.reauthenticateWithPassword(any()),
    ).thenAnswer((_) async {});
    when(() => deletionService.deleteAccount(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await authStateController.close();
  });

  Future<AuthController> signedInAs(AuthProviderType provider) async {
    final identity = AuthIdentity(uid: uid, email: email, provider: provider);
    when(() => authRepository.currentUser).thenReturn(identity);
    when(() => authRepository.signInWithGoogle()).thenAnswer((_) async {
      return identity;
    });
    when(() => authRepository.signInWithApple()).thenAnswer((_) async {
      return identity;
    });
    when(() => userAccountRepository.get(uid)).thenAnswer(
      (_) async => AppUser(
        uid: uid,
        email: email,
        authProvider: provider,
        biometricEnabled: false,
      ),
    );

    final controller = AuthController(
      authRepository: authRepository,
      userAccountRepository: userAccountRepository,
      petProfileRepository: petProfileRepository,
      biometricService: biometricService,
      accountDeletionService: deletionService,
      sharedPreferences: SharedPreferences.getInstance(),
    );
    await controller.initialize();
    await settle();
    return controller;
  }

  group('reauthentication', () {
    test('an email account re-verifies its password first', () async {
      final controller = await signedInAs(AuthProviderType.email);
      final calls = <String>[];
      when(() => authRepository.reauthenticateWithPassword('pw')).thenAnswer((
        _,
      ) async {
        calls.add('reauth');
      });
      when(() => deletionService.deleteAccount(uid)).thenAnswer((_) async {
        calls.add('delete');
      });

      await controller.deleteAccount(password: 'pw');

      expect(calls, ['reauth', 'delete']);
    });

    test('an email account without a password deletes nothing', () async {
      final controller = await signedInAs(AuthProviderType.email);

      await expectLater(
        controller.deleteAccount(),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => deletionService.deleteAccount(any()));
    });

    test('a wrong password stops the deletion', () async {
      final controller = await signedInAs(AuthProviderType.email);
      when(
        () => authRepository.reauthenticateWithPassword('wrong'),
      ).thenThrow(Exception('wrong-password'));

      await expectLater(
        controller.deleteAccount(password: 'wrong'),
        throwsA(isA<Exception>()),
      );

      verifyNever(() => deletionService.deleteAccount(any()));
    });

    test('a Google account redoes its provider sign-in instead', () async {
      // Provider accounts have no app password to re-verify, so the sign-in
      // flow itself is the proof -- and it refreshes the credential Firebase
      // demands before it will delete a user.
      final controller = await signedInAs(AuthProviderType.google);

      await controller.deleteAccount();

      verify(() => authRepository.signInWithGoogle()).called(1);
      verifyNever(() => authRepository.reauthenticateWithPassword(any()));
      verify(() => deletionService.deleteAccount(uid)).called(1);
    });

    test('an Apple account redoes its provider sign-in instead', () async {
      final controller = await signedInAs(AuthProviderType.apple);

      await controller.deleteAccount();

      verify(() => authRepository.signInWithApple()).called(1);
      verify(() => deletionService.deleteAccount(uid)).called(1);
    });
  });

  group('local state', () {
    test('clears what this device remembered about the account', () async {
      final controller = await signedInAs(AuthProviderType.email);

      await controller.deleteAccount(password: 'pw');

      final prefs = await SharedPreferences.getInstance();
      for (final key in AuthPrefsKeys.forAccount(uid)) {
        expect(prefs.get(key), isNull, reason: '$key survived deletion');
      }
    });

    test('leaves preferences that are not account data alone', () async {
      final controller = await signedInAs(AuthProviderType.email);

      await controller.deleteAccount(password: 'pw');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('weight_chart.show_table'), isTrue);
    });

    test('keeps the remembered email when deletion fails', () async {
      // The account still exists, so the user is still signed in to it --
      // wiping the device's memory of it would be a confusing half-logout
      // on top of a failure they are expected to retry.
      final controller = await signedInAs(AuthProviderType.email);
      when(
        () => deletionService.deleteAccount(uid),
      ).thenThrow(Exception('backend down'));

      await expectLater(
        controller.deleteAccount(password: 'pw'),
        throwsA(isA<Exception>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthPrefsKeys.rememberedEmail), email);
    });
  });

  test('refuses when there is no signed-in user', () async {
    when(() => authRepository.currentUser).thenReturn(null);
    final controller = AuthController(
      authRepository: authRepository,
      userAccountRepository: userAccountRepository,
      petProfileRepository: petProfileRepository,
      biometricService: biometricService,
      accountDeletionService: deletionService,
      sharedPreferences: SharedPreferences.getInstance(),
    );
    await controller.initialize();

    await expectLater(controller.deleteAccount(), throwsA(isA<StateError>()));
    verifyNever(() => deletionService.deleteAccount(any()));
  });
}
