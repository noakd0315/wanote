/// No-op on every platform except web -- see
/// `auth_emulator_seed_web.dart` for why the web build needs to do
/// something before `Firebase.initializeApp()`. On Android/iOS/desktop,
/// `FirebaseAuth.useAuthEmulator()` after initialization works fine.
void seedAuthEmulatorOrigin(String origin) {}
