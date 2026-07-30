import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/home_shell.dart';
import 'features/auth/auth.dart';
import 'shared/config/emulator_config.dart';
import 'shared/config/firebase_options_demo.dart';

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
      ],
      child: MaterialApp(
        title: 'wanote',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: LaunchGateScreen(
          homeBuilder: (context) {
            final controller = context.watch<AuthController>();
            final uid = controller.currentUser?.uid;
            final activePet = controller.activePet;

            // Defensive fallbacks only: LaunchGateScreen already guarantees
            // a signed-in user with at least one pet before it ever calls
            // homeBuilder (see its `gateAction == enterApp` /
            // `pets.isEmpty` checks in launch_gate_screen.dart). These
            // branches guard against a narrow race (e.g. the active pet
            // being deleted out from under the stream) rather than assuming
            // it can never happen.
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
    );
  }
}
