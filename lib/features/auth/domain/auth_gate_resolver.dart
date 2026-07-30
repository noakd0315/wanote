/// What the launch screen should show, decided purely from state — no
/// Firebase/local_auth calls happen here, which is what makes this testable
/// in isolation (see test/features/auth/domain/auth_gate_resolver_test.dart).
enum AuthGateAction {
  /// No signed-in session: show the registration/sign-in screen.
  requireSignIn,

  /// Signed in, biometric lock is on and the device supports it: show the
  /// biometric prompt before revealing app content.
  requireBiometric,

  /// Signed in, and either biometric is disabled or unsupported on this
  /// device: skip straight to the app (spec 1.4 — "自動的にパスワード認証
  /// のみの導線にする", i.e. no extra gate beyond the already-persisted
  /// Firebase session).
  enterApp,
}

class AuthGateResolver {
  const AuthGateResolver();

  AuthGateAction resolve({
    required bool hasActiveSession,
    required bool biometricEnabled,
    required bool biometricAvailable,
  }) {
    if (!hasActiveSession) {
      return AuthGateAction.requireSignIn;
    }
    if (biometricEnabled && biometricAvailable) {
      return AuthGateAction.requireBiometric;
    }
    return AuthGateAction.enterApp;
  }
}
