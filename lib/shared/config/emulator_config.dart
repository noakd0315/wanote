import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Set via `--dart-define=USE_FIREBASE_EMULATOR=true` to point every Firebase
/// SDK call at the Firebase Local Emulator Suite (see docker-compose.yml)
/// instead of a real project. This is what lets the app run end-to-end
/// without any real Firebase/GCP account.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Host to reach the emulators at. Defaults to localhost (works for
/// flutter web/desktop and for docker-compose's host-mapped ports). Override
/// with `--dart-define=EMULATOR_HOST=10.0.2.2` when running on the Android
/// emulator (which can't see the host machine as "localhost"), or with the
/// host machine's LAN IP for a physical device.
const String emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: 'localhost',
);

/// Must be called once, after `Firebase.initializeApp()` and before any
/// other Firebase SDK usage, whenever [useFirebaseEmulator] is true.
Future<void> connectToFirebaseEmulatorsIfEnabled() async {
  if (!useFirebaseEmulator) return;
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
}
