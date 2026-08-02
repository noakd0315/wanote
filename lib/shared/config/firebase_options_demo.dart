import 'package:firebase_core/firebase_core.dart';

/// Placeholder Firebase project config used ONLY when running against the
/// Firebase Local Emulator Suite (see docker-compose.yml / firebase.json,
/// which are configured with the matching project id "demo-wanote"). The
/// emulators don't validate most of these fields, so they can be arbitrary
/// placeholder strings — but `projectId` MUST stay in sync with whatever
/// project id the emulator suite is started with.
///
/// Never use this for a real build against production Firebase. A real
/// project's config comes from running `flutterfire configure`, which
/// generates `lib/firebase_options.dart` (gitignored, machine-specific) —
/// main.dart should prefer that file when it exists and only fall back to
/// this one when running with `--dart-define=USE_FIREBASE_EMULATOR=true`.
///
/// `apiKey` must *look* like a real Google API key (`AIza` + 35 more
/// chars) even though the emulator never checks it server-side: the
/// Firebase JS SDK (used under the hood by firebase_auth_web) validates the
/// key's shape client-side before making any request and rejects anything
/// that doesn't match with `auth/api-key-not-valid.-please-pass-a-valid-api-key.`
/// — caught while signing in against the emulator in a real browser.
const FirebaseOptions demoFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDemoEmulatorPlaceholderKey0000000',
  appId: '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-wanote',
  storageBucket: 'demo-wanote.appspot.com',
);
