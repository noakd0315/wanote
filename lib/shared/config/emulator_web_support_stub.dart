/// Non-web builds: nothing to do here.
///
/// On Android/iOS/desktop `FirebaseAuth.useAuthEmulator()` works normally
/// after `Firebase.initializeApp()`, so none of the web workarounds in
/// `emulator_web_support_web.dart` are needed. See that file for what the
/// web build has to do instead, and why.
library;

/// Host that local dev services (the Firebase emulators, `wrangler dev`)
/// are reached at. Off the web there is no page to take a hint from.
String localDevHost() => 'localhost';

/// No-op off the web.
void routeAuthRequestsToEmulator(String origin) {}
