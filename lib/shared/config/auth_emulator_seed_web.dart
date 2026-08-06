import 'package:web/web.dart' as web;

/// Web-only workaround: on web, `FirebaseAuth.instance.useAuthEmulator()`
/// silently does nothing when called after `Firebase.initializeApp()`.
///
/// `firebase_core_web` runs firebase_auth_web's `ensurePluginInitialized`
/// during `initializeApp`, and that awaits the JS SDK's
/// `onWaitInitState()`. Once auth has finished initializing, the JS SDK's
/// `connectAuthEmulator()` throws `auth/emulator-config-failed` -- and
/// firebase_auth_web *swallows* exactly that code (it treats it as the
/// harmless hot-reload case). So the call returns normally while every
/// request still goes to the real `identitytoolkit.googleapis.com`, which
/// answers "API key not valid" for our placeholder demo key. Sign-in just
/// fails with no clue as to why.
///
/// The one path that does work is the one firebase_auth_web uses to survive
/// a page refresh: it re-applies the emulator during `ensurePluginInitialized`
/// if it finds the origin in session storage. Writing that key *before*
/// `Firebase.initializeApp()` makes the very first page load take the same
/// path, so the emulator is connected while the JS SDK still allows it.
///
/// Note the plugin only reads the key when `hostname == 'localhost'` and in
/// debug mode, so serve the app from `localhost` (not `127.0.0.1`) when
/// running against the emulators.
void seedAuthEmulatorOrigin(String origin) {
  // Key format taken from firebase_auth_web's getOriginName(); '[DEFAULT]'
  // is the default FirebaseApp's name.
  web.window.sessionStorage.setItem('[DEFAULT]-firebaseEmulatorOrigin', origin);
}
