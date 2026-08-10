import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'emulator_web_support_stub.dart'
    if (dart.library.js_interop) 'emulator_web_support_web.dart';

/// Set via `--dart-define=USE_FIREBASE_EMULATOR=true` to point every Firebase
/// SDK call at the Firebase Local Emulator Suite (see docker-compose.yml)
/// instead of a real project. This is what lets the app run end-to-end
/// without any real Firebase/GCP account.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

const String _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

/// Host to reach the emulators at.
///
/// Defaults to the host that served the page on web (so opening the app from
/// a phone at `http://192.168.x.x:5000` reaches the emulators on the dev
/// machine, not on the phone) and to localhost everywhere else. Override with
/// `--dart-define=EMULATOR_HOST=10.0.2.2` on the Android emulator, which
/// cannot see the host machine as "localhost".
String get emulatorHost =>
    _emulatorHostOverride.isNotEmpty ? _emulatorHostOverride : localDevHost();

/// Must be called once, *before* `Firebase.initializeApp()`, whenever
/// [useFirebaseEmulator] is true.
///
/// On web this is the only point at which Auth requests can still be diverted
/// to the emulator -- `Firebase.initializeApp()` initializes the JS SDK's Auth
/// on the way through, and after that the SDK refuses to be pointed at an
/// emulator. See `emulator_web_support_web.dart` for the full story. No-op
/// everywhere else, where the ordinary [connectToFirebaseEmulatorsIfEnabled]
/// call below is enough.
void prepareFirebaseEmulatorsIfEnabled() {
  if (!useFirebaseEmulator) return;
  routeAuthRequestsToEmulator('http://$emulatorHost:9099');
}

/// Must be called once, after `Firebase.initializeApp()` and before any
/// other Firebase SDK usage, whenever [useFirebaseEmulator] is true.
Future<void> connectToFirebaseEmulatorsIfEnabled() async {
  if (!useFirebaseEmulator) return;
  final host = emulatorHost;
  // Skipped on web on purpose: there the call cannot work (and quietly
  // pretends it did), so Auth is handled by
  // [prepareFirebaseEmulatorsIfEnabled] instead. Firestore and Storage below
  // have no such problem -- they accept an emulator after initialization.
  if (!kIsWeb) {
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }
  // 8081, not the emulator's usual 8080: docker-compose.yml maps host 8081
  // -> container 8080 because 8080 is already taken by an unrelated
  // container on the dev machine. See the comment there for details.
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
}
