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
    SharedPreferences.setMockInitialValues({});
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
      await controller.initialize();
      await tester.pumpAndSettle();

      // No pets yet -> LaunchGateScreen must show the forced first-pet form
      // (PetProfileFormScreen's "Add a pet" app bar) rather than ever
      // reaching the app shell with a null active pet.
      expect(find.text('Add a pet'), findsOneWidget);
      expect(controller.pets, isEmpty);
      expect(controller.activePet, isNull);
    },
  );
}
