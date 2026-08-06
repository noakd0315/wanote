import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/home_shell.dart';
import 'features/auth/auth.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/config/emulator_config.dart';
import 'shared/config/firebase_options_demo.dart';
import 'shared/services/locale_controller.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(firebase-setup): No real Firebase project has been provisioned yet
  // (nobody has run `flutterfire configure`), so `lib/firebase_options.dart`
  // (gitignored, machine-generated) does not exist in this checkout. We
  // cannot conditionally import a file that may not exist -- that fails to
  // compile for anyone without it -- so for now every build always
  // initializes against `demoFirebaseOptions` (see
  // shared/config/firebase_options_demo.dart), which only really works
  // against the Firebase Local Emulator Suite via
  // `connectToFirebaseEmulatorsIfEnabled()` below.
  //
  // Once a real Firebase project exists and `flutterfire configure` has been
  // run, this should become:
  //
  //   options: useFirebaseEmulator
  //       ? demoFirebaseOptions
  //       : DefaultFirebaseOptions.currentPlatform
  //
  // (with an `import 'firebase_options.dart';` added back above).
  // Must straddle initializeApp: on web the Auth emulator can only be
  // attached before it, the other emulators only after it.
  prepareFirebaseEmulatorsIfEnabled();
  await Firebase.initializeApp(options: demoFirebaseOptions);
  await connectToFirebaseEmulatorsIfEnabled();

  runApp(const WanoteApp());
}

/// Root widget: wires the app-wide [AuthController] via `provider` and hands
/// the real app shell ([HomeShell]) to [LaunchGateScreen] as its
/// `homeBuilder`, so LaunchGateScreen keeps handling sign-in / biometric
/// gate / forced onboarding (first pet profile) before anything in
/// `lib/app/` is ever reached.
class WanoteApp extends StatelessWidget {
  const WanoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            authRepository: FirebaseAuthRepository(),
            userAccountRepository: FirestoreUserAccountRepository(),
            petProfileRepository: FirestorePetProfileRepository(),
            biometricService: LocalAuthBiometricService(),
          )..initialize(),
        ),
        ChangeNotifierProvider<LocaleController>(
          create: (_) => LocaleController(),
        ),
      ],
      child: Consumer<LocaleController>(
        builder: (context, localeController, _) => MaterialApp(
          title: 'wanote',
          theme: buildWanoteTheme(),
          // Shipaton targets a global audience (spec section on i18n), so
          // UI text follows the device's own language setting by default
          // rather than the App/Play Store account's billing region -- see
          // the PM conversation this was scoped from for why store region
          // isn't a reliable signal for language preference. `locale` is
          // left null (falls back to system locale resolution) unless the
          // user picked an explicit override via LanguageIconButton /
          // showLanguagePicker (sign-in screen, settings screen). Only
          // en/ja are translated so far (infra + sign-in/settings screens
          // as the model case); everything else still falls back to
          // whatever's hardcoded until migrated screen-by-screen.
          locale: localeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LaunchGateScreen(
            homeBuilder: (context) {
              final controller = context.watch<AuthController>();
              final uid = controller.currentUser?.uid;
              final activePet = controller.activePet;

              // Defensive fallbacks only: LaunchGateScreen already
              // guarantees a signed-in user with at least one pet before it
              // ever calls homeBuilder (see its `gateAction == enterApp` /
              // `pets.isEmpty` checks in launch_gate_screen.dart). These
              // branches guard against a narrow race (e.g. the active pet
              // being deleted out from under the stream) rather than
              // assuming it can never happen.
              if (uid == null) {
                return const SignUpScreen();
              }
              if (activePet == null) {
                return const PetProfileFormScreen();
              }
              return HomeShell(uid: uid, activePet: activePet);
            },
          ),
        ),
      ),
    );
  }
}
