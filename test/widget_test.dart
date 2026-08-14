// App-shell smoke tests.
//
// main.dart wires AuthController (built on real Firebase-backed
// repositories) into LaunchGateScreen; that composition can't run under
// flutter_test without a real Firebase app, so these tests instead build the
// same AuthController + LaunchGateScreen composition main.dart uses, but
// with mocked repositories -- following the same mocktail pattern already
// established in test/features/auth/presentation/auth_controller_test.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanote/features/auth/auth.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserAccountRepository extends Mock implements UserAccountRepository {}

class MockPetProfileRepository extends Mock implements PetProfileRepository {}

class MockBiometricService extends Mock implements BiometricService {}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProviderType.email);
  });

  late MockAuthRepository authRepository;
  late MockUserAccountRepository userAccountRepository;
  late MockPetProfileRepository petProfileRepository;
  late MockBiometricService biometricService;
  late StreamController<AuthIdentity?> authStateController;
  late AuthController controller;

  setUp(() {
    // Session-expiry window: these tests exercise the *gate*, not the
    // expiry, so give them a session authenticated just now. Without a
    // recorded authentication SessionExpiryPolicy treats the session as
    // of unknown age and requires signing in again -- see
    // test/features/auth/presentation/session_expiry_controller_test.dart.
    SharedPreferences.setMockInitialValues({
      'auth.last_authenticated_at.uid-1': DateTime.now().toIso8601String(),
    });
    authRepository = MockAuthRepository();
    userAccountRepository = MockUserAccountRepository();
    petProfileRepository = MockPetProfileRepository();
    biometricService = MockBiometricService();
    authStateController = StreamController<AuthIdentity?>.broadcast();

    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => authStateController.stream);
    when(
      () => userAccountRepository.watchActiveSessionId(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => userAccountRepository.setActiveSession(
        uid: any(named: 'uid'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async {});

    controller = AuthController(
      authRepository: authRepository,
      userAccountRepository: userAccountRepository,
      petProfileRepository: petProfileRepository,
      biometricService: biometricService,
      sharedPreferences: SharedPreferences.getInstance(),
    );
  });

  tearDown(() async {
    controller.dispose();
    await authStateController.close();
  });

  Future<void> pumpLaunchGate(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LaunchGateScreen(),
        ),
      ),
    );
  }

  testWidgets(
    'LaunchGateScreen renders the sign-in screen (not sign-up) when there is no session',
    (tester) async {
      when(() => authRepository.currentUser).thenReturn(null);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => false);

      await controller.initialize();
      await pumpLaunchGate(tester);
      await tester.pump();

      // PM request: the app's initial screen should be sign-in, not
      // registration.
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Create your account'), findsNothing);
      expect(controller.gateAction, AuthGateAction.requireSignIn);
    },
  );

  testWidgets(
    'LaunchGateScreen forces pet creation for a signed-in user with no pets',
    (tester) async {
      const identity = AuthIdentity(
        uid: 'uid-1',
        email: 'owner@example.com',
        provider: AuthProviderType.email,
      );

      when(() => authRepository.currentUser).thenReturn(identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => true);
      when(() => userAccountRepository.get(identity.uid)).thenAnswer(
        (_) async => const AppUser(
          uid: 'uid-1',
          email: 'owner@example.com',
          authProvider: AuthProviderType.email,
          biometricEnabled: false,
        ),
      );
      // A single-value stream (rather than a manually-driven
      // StreamController + raw Future.delayed) avoids the classic
      // testWidgets trap where a bare `Future.delayed` never fires because
      // AutomatedTestWidgetsFlutterBinding only advances real timers via
      // tester.pump()/pumpAndSettle().
      when(
        () => petProfileRepository.watchPets(identity.uid),
      ).thenAnswer((_) => Stream.value(const <PetProfile>[]));

      await pumpLaunchGate(tester);
      // runAsync, not a bare await: initialize() now reads SharedPreferences
      // for the session-expiry timestamp, and a platform-channel reply is
      // only delivered while the tester is pumping -- awaiting it directly
      // deadlocks the test.
      await tester.runAsync(() => controller.initialize());
      await tester.pumpAndSettle();

      // No pets yet -> LaunchGateScreen must show the forced first-pet form
      // (PetProfileFormScreen's "Add a pet" app bar) rather than ever
      // reaching the app shell with a null active pet.
      expect(find.text('Add a pet'), findsOneWidget);
      expect(controller.pets, isEmpty);
      expect(controller.activePet, isNull);
    },
  );

  testWidgets('LaunchGateScreen waits instead of claiming there is no session', (
    tester,
  ) async {
    // Nothing has been resolved yet -- exactly the state the app is in when
    // Android rebuilds it after killing it in the background, which taking a
    // photo is enough to cause. gateAction still holds its starting value of
    // requireSignIn, and rendering that put the sign-in screen in front of
    // owners who had never signed out.
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => biometricService.isAvailable()).thenAnswer((_) async => false);

    await pumpLaunchGate(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets(
    'LaunchGateScreen waits for the pet list rather than showing the first-pet form',
    (tester) async {
      const identity = AuthIdentity(
        uid: 'uid-1',
        email: 'owner@example.com',
        provider: AuthProviderType.email,
      );
      final pets = StreamController<List<PetProfile>>();
      addTearDown(pets.close);

      when(() => authRepository.currentUser).thenReturn(identity);
      when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
      when(() => userAccountRepository.get(identity.uid)).thenAnswer(
        (_) async => const AppUser(
          uid: 'uid-1',
          email: 'owner@example.com',
          authProvider: AuthProviderType.email,
          biometricEnabled: false,
        ),
      );
      when(
        () => petProfileRepository.watchPets(identity.uid),
      ).thenAnswer((_) => pets.stream);

      await pumpLaunchGate(tester);
      await tester.runAsync(() => controller.initialize());
      // pump, never pumpAndSettle, while the waiting screen is up: its
      // progress indicator animates forever, so "settled" never arrives.
      await tester.pump();

      // Signed in, but the list has not arrived. "Not arrived" is not "no
      // pets": showing the first-pet form here is what greeted returning
      // owners on every sign-in, and it reads as their dogs being gone.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Add a pet'), findsNothing);

      pets.add(const <PetProfile>[]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      // Now it is a real answer, and the form is the right screen.
      expect(find.text('Add a pet'), findsOneWidget);
    },
  );

  testWidgets('LaunchGateScreen does not wait forever if the pet list fails', (
    tester,
  ) async {
    const identity = AuthIdentity(
      uid: 'uid-1',
      email: 'owner@example.com',
      provider: AuthProviderType.email,
    );
    final pets = StreamController<List<PetProfile>>();
    addTearDown(pets.close);

    when(() => authRepository.currentUser).thenReturn(identity);
    when(() => biometricService.isAvailable()).thenAnswer((_) async => false);
    when(() => userAccountRepository.get(identity.uid)).thenAnswer(
      (_) async => const AppUser(
        uid: 'uid-1',
        email: 'owner@example.com',
        authProvider: AuthProviderType.email,
        biometricEnabled: false,
      ),
    );
    when(
      () => petProfileRepository.watchPets(identity.uid),
    ).thenAnswer((_) => pets.stream);

    await pumpLaunchGate(tester);
    await tester.runAsync(() => controller.initialize());
    await tester.pump();

    // Offline, or rules refusing the read. Waiting on an answer that is
    // never coming would strand the owner on a spinner with no way out.
    pets.addError(Exception('permission-denied'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Add a pet'), findsOneWidget);
  });
}
