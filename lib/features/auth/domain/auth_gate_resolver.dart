/// What the launch screen should show, decided purely from state — no
/// Firebase/local_auth calls happen here, which is what makes this testable
/// in isolation (see test/features/auth/domain/auth_gate_resolver_test.dart).
///
/// See [SessionExpiryPolicy] for where `sessionExpired` comes from.
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

  /// [sessionExpired] comes from [SessionExpiryPolicy]: the user has not
  /// proved who they are for longer than the allowed window.
  ///
  /// An expired session does not always mean signing in again. Where
  /// biometrics are set up, the biometric prompt *is* the re-authentication
  /// -- it already proves the phone's owner is present, which is what the
  /// window exists to re-establish (PM: "完全ログアウトではなく、生体認証で
  /// 通過で問題ないです"). Only a device with no biometric to fall back on
  /// gets sent all the way back to sign-in.
  AuthGateAction resolve({
    required bool hasActiveSession,
    required bool biometricEnabled,
    required bool biometricAvailable,
    bool sessionExpired = false,
  }) {
    if (!hasActiveSession) {
      return AuthGateAction.requireSignIn;
    }
    if (biometricEnabled && biometricAvailable) {
      return AuthGateAction.requireBiometric;
    }
    if (sessionExpired) {
      return AuthGateAction.requireSignIn;
    }
    return AuthGateAction.enterApp;
  }
}
