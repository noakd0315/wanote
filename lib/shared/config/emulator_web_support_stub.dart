/// Non-web builds: nothing to do here.
///
/// On Android/iOS/desktop `FirebaseAuth.useAuthEmulator()` works normally
/// after `Firebase.initializeApp()`, so none of the web workarounds in
/// `emulator_web_support_web.dart` are needed. See that file for what the
/// web build has to do instead, and why.
library;

/// Host to reach the emulators at when no `EMULATOR_HOST` is given.
String defaultEmulatorHost() => 'localhost';

/// No-op off the web.
void routeAuthRequestsToEmulator(String origin) {}
