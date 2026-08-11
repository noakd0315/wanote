import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanote/features/auth/data/auth_repository.dart';
import 'package:wanote/features/auth/data/biometric_service.dart';
import 'package:wanote/features/auth/data/pet_profile_repository.dart';
import 'package:wanote/features/auth/data/user_account_repository.dart';
import 'package:wanote/features/auth/domain/auth_gate_resolver.dart';
import 'package:wanote/features/auth/presentation/auth_controller.dart';
import 'package:wanote/shared/models/app_user.dart';
import 'package:wanote/shared/models/auth_provider_type.dart';
import 'package:wanote/shared/models/pet_profile.dart';

/// PM request: expire a session a day after the last authentication, but let
/// biometrics stand in for signing in again.
///
/// What the pure SessionExpiryPolicy test cannot cover is the wiring: which
/// events restart the window. Getting that wrong is invisible -- if merely
/// resuming a session refreshed the timestamp, a phone opened daily would
/// never expire, and the feature would look implemented while doing nothing.

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
const _lastAuthKey = 'auth.last_authenticated_at.uid-1';

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProviderType.email);
  });

  late MockAuthRepository authRepository;
  late MockUserAccountRepository userAccountRepository;
  late MockPetProfileRepository petProfileRepository;
  late MockBiometricService biometricService;
  late StreamController<AuthIdentity?> authStateController;
  late DateTime now;

  void setUpWith({
    required bool biometricEnabled,
    bool biometricAvailable = false,
  }) {
    authRepository = MockAuthRepository();
    userAccountRepository = MockUserAccountRepository();
    petProfileRepository = MockPetProfileRepository();
    biometricService = MockBiometricService();
    authStateController = StreamController<AuthIdentity?>.broadcast();

    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => authStateController.stream);
    when(() => authRepository.currentUser).thenReturn(_identity);
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    when(
      () => authRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _identity);
    when(
      () => biometricService.isAvailable(),
    ).thenAnswer((_) async => biometricAvailable);
    when(
      () => petProfileRepository.watchPets(any()),
    ).thenAnswer((_) => const Stream<List<PetProfile>>.empty());
    when(() => userAccountRepository.get(_uid)).thenAnswer(
      (_) async => AppUser(
        uid: _uid,
        email: _email,
        authProvider: AuthProviderType.email,
        biometricEnabled: biometricEnabled,
      ),
    );
    when(
      () => userAccountRepository.watchActiveSessionId(_uid),
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(
      () => userAccountRepository.setActiveSession(
        uid: any(named: 'uid'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async {});
  }

  tearDown(() async {
    await authStateController.close();
  });

  AuthController buildController() => AuthController(
    authRepository: authRepository,
    userAccountRepository: userAccountRepository,
    petProfileRepository: petProfileRepository,
    biometricService: biometricService,
    sharedPreferences: SharedPreferences.getInstance(),
    now: () => now,
  );

  test('a session authenticated today enters the app', () async {
    now = DateTime(2026, 8, 11, 12);
    SharedPreferences.setMockInitialValues({
      _lastAuthKey: DateTime(2026, 8, 11, 9).toIso8601String(),
    });
    setUpWith(biometricEnabled: false);

    final controller = buildController();
    await controller.initialize();

    expect(controller.gateAction, AuthGateAction.enterApp);
  });

  test('a session older than a day is sent back to sign-in', () async {
    now = DateTime(2026, 8, 11, 12);
    SharedPreferences.setMockInitialValues({
      _lastAuthKey: DateTime(2026, 8, 9, 12).toIso8601String(),
    });
    setUpWith(biometricEnabled: false);

    final controller = buildController();
    await controller.initialize();

    expect(controller.gateAction, AuthGateAction.requireSignIn);
  });

  test(
    'a stale session with biometrics asks for a fingerprint, not a password',
    () async {
      // PM: biometrics may stand in for a full sign-out.
      now = DateTime(2026, 8, 11, 12);
      SharedPreferences.setMockInitialValues({
        _lastAuthKey: DateTime(2026, 8, 1).toIso8601String(),
      });
      setUpWith(biometricEnabled: true, biometricAvailable: true);

      final controller = buildController();
      await controller.initialize();

      expect(controller.gateAction, AuthGateAction.requireBiometric);
    },
  );

  test('signing in restarts the window', () async {
    now = DateTime(2026, 8, 11, 12);
    SharedPreferences.setMockInitialValues({
      _lastAuthKey: DateTime(2026, 8, 1).toIso8601String(),
    });
    setUpWith(biometricEnabled: false);

    final controller = buildController();
    await controller.initialize();
    expect(controller.gateAction, AuthGateAction.requireSignIn);

    await controller.signInWithEmail(email: _email, password: 'password1');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAuthKey), now.toIso8601String());
    expect(controller.gateAction, AuthGateAction.enterApp);
  });

  test('resuming a persisted session does NOT restart the window', () async {
    // The whole point: if opening the app refreshed the timestamp, a phone
    // used daily would never re-authenticate and the window would be
    // decorative.
    now = DateTime(2026, 8, 11, 12);
    final original = DateTime(2026, 8, 11, 9).toIso8601String();
    SharedPreferences.setMockInitialValues({_lastAuthKey: original});
    setUpWith(biometricEnabled: false);

    final controller = buildController();
    await controller.initialize();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAuthKey), original);
  });

  test(
    'a session that ages out in the background is caught on resume',
    () async {
      now = DateTime(2026, 8, 11, 12);
      SharedPreferences.setMockInitialValues({
        _lastAuthKey: DateTime(2026, 8, 11, 9).toIso8601String(),
      });
      setUpWith(biometricEnabled: false);

      final controller = buildController();
      await controller.initialize();
      expect(controller.gateAction, AuthGateAction.enterApp);

      // Two days pass with the app in the background.
      now = DateTime(2026, 8, 13, 12);
      await controller.refreshSessionGate();

      verify(() => authRepository.signOut()).called(1);
    },
  );

  test('resume leaves a still-fresh session alone', () async {
    now = DateTime(2026, 8, 11, 12);
    SharedPreferences.setMockInitialValues({
      _lastAuthKey: DateTime(2026, 8, 11, 9).toIso8601String(),
    });
    setUpWith(biometricEnabled: false);

    final controller = buildController();
    await controller.initialize();

    now = DateTime(2026, 8, 11, 20);
    await controller.refreshSessionGate();

    expect(controller.gateAction, AuthGateAction.enterApp);
    verifyNever(() => authRepository.signOut());
  });
}
