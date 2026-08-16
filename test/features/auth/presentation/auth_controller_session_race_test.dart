import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanote/features/auth/data/auth_repository.dart';
import 'package:wanote/features/auth/data/biometric_service.dart';
import 'package:wanote/features/auth/data/pet_profile_repository.dart';
import 'package:wanote/features/auth/data/user_account_repository.dart';
import 'package:wanote/features/auth/presentation/auth_controller.dart';
import 'package:wanote/shared/models/app_user.dart';
import 'package:wanote/shared/models/auth_provider_type.dart';
import 'package:wanote/shared/models/pet_profile.dart';

/// Reproduction for the PM report: "ログイン後ブラウザバック等でログイン画面に
/// 戻った場合、正しいパスワードを入力してもエラーになってしまいます".
///
/// The key difference from auth_controller_test.dart's mocks is
/// [_FakeActiveSessionStore], which models how Firestore's `.snapshots()`
/// *actually* behaves: it emits the document's CURRENT value immediately on
/// subscribe, before any subsequent writes. The existing tests use
/// `Stream.empty()` or a manually-driven controller that never replays the
/// stored value, which is exactly why this bug slipped through.

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
const _localSessionKey = 'auth.local_session_id.$_uid';

/// Stands in for the `active_session_id` field on the account's Firestore
/// doc, with Firestore's real subscribe-then-replay-current-value semantics.
class _FakeActiveSessionStore {
  _FakeActiveSessionStore(this._value);

  String? _value;
  final _listeners = <StreamController<String?>>[];

  String? get value => _value;

  Stream<String?> watch() {
    late final StreamController<String?> controller;
    controller = StreamController<String?>(
      onListen: () {
        // Firestore replays the current snapshot to every new listener.
        controller.add(_value);
      },
    );
    _listeners.add(controller);
    return controller.stream;
  }

  Future<void> set(String sessionId) async {
    _value = sessionId;
    for (final controller in _listeners) {
      if (!controller.isClosed) controller.add(sessionId);
    }
  }

  Future<void> dispose() async {
    for (final controller in _listeners) {
      await controller.close();
    }
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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
  late _FakeActiveSessionStore sessionStore;

  void setUpWith({required String? existingRemoteSession}) {
    authRepository = MockAuthRepository();
    userAccountRepository = MockUserAccountRepository();
    petProfileRepository = MockPetProfileRepository();
    biometricService = MockBiometricService();
    authStateController = StreamController<AuthIdentity?>.broadcast();
    petsController = StreamController<List<PetProfile>>.broadcast();
    sessionStore = _FakeActiveSessionStore(existingRemoteSession);

    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => authStateController.stream);
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    when(
      () => authRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _identity);
    when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
    when(
      () => petProfileRepository.watchPets(any()),
    ).thenAnswer((_) => petsController.stream);
    when(() => userAccountRepository.get(_uid)).thenAnswer(
      (_) async => const AppUser(
        uid: _uid,
        email: _email,
        authProvider: AuthProviderType.email,
        biometricEnabled: false,
      ),
    );
    when(
      () => userAccountRepository.watchActiveSessionId(_uid),
    ).thenAnswer((_) => sessionStore.watch());
    when(
      () => userAccountRepository.setActiveSession(
        uid: any(named: 'uid'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((invocation) async {
      await sessionStore.set(invocation.namedArguments[#sessionId] as String);
    });
  }

  tearDown(() async {
    await authStateController.close();
    await petsController.close();
    await sessionStore.dispose();
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

  test('signing in again on the same device does not force-sign-out '
      '(account already has an active session from this device)', () async {
    // This device signed in earlier: both Firestore and this device's
    // local prefs already hold session-1. Then the user ends up back on
    // the sign-in screen (browser back) and signs in again.
    SharedPreferences.setMockInitialValues({_localSessionKey: 'session-1'});
    setUpWith(existingRemoteSession: 'session-1');

    final controller = buildController();
    await controller.initialize();
    await controller.signInWithEmail(email: _email, password: 'password1');
    await _settle();

    expect(
      controller.wasForcedSignedOut,
      isFalse,
      reason:
          'Re-signing in on the SAME device must not be mistaken for a '
          'different device taking over the account.',
    );
    verifyNever(() => authRepository.signOut());
  });

  test('first-ever sign-in on a fresh account is unaffected '
      '(explains why only the SECOND sign-in fails)', () async {
    // No prior session anywhere: Firestore has no active_session_id yet.
    SharedPreferences.setMockInitialValues({});
    setUpWith(existingRemoteSession: null);

    final controller = buildController();
    await controller.initialize();
    await controller.signInWithEmail(email: _email, password: 'password1');
    await _settle();

    expect(controller.wasForcedSignedOut, isFalse);
    verifyNever(() => authRepository.signOut());
  });

  test('auth stream replaying the same sign-in concurrently does not '
      'trigger a false takeover', () async {
    // Real Firebase Auth fires authStateChanges() as part of a successful
    // signInWithEmail, so _onAuthChanged runs twice for one sign-in: once
    // from the stream and once from _runAuthAction. Model that here.
    SharedPreferences.setMockInitialValues({_localSessionKey: 'session-1'});
    setUpWith(existingRemoteSession: 'session-1');
    when(
      () => authRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      authStateController.add(_identity);
      return _identity;
    });

    final controller = buildController();
    await controller.initialize();
    await controller.signInWithEmail(email: _email, password: 'password1');
    await _settle();

    expect(controller.wasForcedSignedOut, isFalse);
    verifyNever(() => authRepository.signOut());
  });

  test(
    'a genuinely different device claiming the session still signs this one out',
    () async {
      SharedPreferences.setMockInitialValues({_localSessionKey: 'session-1'});
      setUpWith(existingRemoteSession: 'session-1');

      final controller = buildController();
      await controller.initialize();
      await controller.signInWithEmail(email: _email, password: 'password1');
      await _settle();

      // Another device claims the account.
      await sessionStore.set('another-devices-session');
      await _settle();

      expect(controller.wasForcedSignedOut, isTrue);
      verify(() => authRepository.signOut()).called(1);
    },
  );
  test(
    'claims the account remotely before recording the session locally',
    () async {
      // The two writes are not atomic and the app can die between them -- a
      // browser tab killed for memory is the case that prompted this. If the
      // local copy went first, a crash in the gap would leave Firestore
      // pointing at the *previous* device, which would therefore stay signed
      // in: the exact outcome single-session enforcement exists to prevent.
      SharedPreferences.setMockInitialValues({_localSessionKey: 'session-old'});
      setUpWith(existingRemoteSession: 'session-old');

      String? localSessionWhenRemoteWasWritten;
      when(
        () => userAccountRepository.setActiveSession(
          uid: any(named: 'uid'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((invocation) async {
        final prefs = await SharedPreferences.getInstance();
        localSessionWhenRemoteWasWritten = prefs.getString(_localSessionKey);
        await sessionStore.set(invocation.namedArguments[#sessionId] as String);
      });

      final controller = buildController();
      await controller.initialize();
      await controller.signInWithEmail(email: _email, password: 'password1');
      await _settle();

      expect(
        localSessionWhenRemoteWasWritten,
        'session-old',
        reason:
            'The local copy must still be the old one at the moment the '
            'account is claimed remotely.',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_localSessionKey),
        isNot('session-old'),
        reason: 'Both writes must still happen -- only their order changed.',
      );
      expect(prefs.getString(_localSessionKey), sessionStore.value);
    },
  );

  test(
    'a listener that opens mid-claim does not read the claim as a takeover',
    () async {
      // The window this test covers is the one the PM signed in through:
      // the account doc already says the new session id while this device's
      // own copy still says the old one.
      //
      // The generation counter does not close it. That is bumped before the
      // writes, so a subscription opened during the claim carries the
      // current generation and is treated as live -- and what it reads in
      // that moment is indistinguishable from another device taking over.
      //
      // Reproduced by firing the auth stream from inside the remote write,
      // which is when Firebase Auth really does fire it: the sign-in call
      // and the stream both drive _onAuthChanged, concurrently.
      SharedPreferences.setMockInitialValues({_localSessionKey: 'session-old'});
      setUpWith(existingRemoteSession: 'session-old');

      when(
        () => userAccountRepository.setActiveSession(
          uid: any(named: 'uid'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((invocation) async {
        authStateController.add(_identity);
        await _settle();
        await sessionStore.set(invocation.namedArguments[#sessionId] as String);
        await _settle();
      });

      final controller = buildController();
      await controller.initialize();
      await controller.signInWithEmail(email: _email, password: 'password1');
      await _settle();

      expect(
        controller.wasForcedSignedOut,
        isFalse,
        reason:
            'The device claimed the session itself. Seeing its own claim '
            'arrive before it finished writing it down is not a takeover.',
      );
      verifyNever(() => authRepository.signOut());
    },
  );
}
