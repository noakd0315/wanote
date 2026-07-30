import '../../../shared/models/auth_provider_type.dart';
import '../data/biometric_service.dart';

/// What to do after a biometric prompt attempt finishes.
enum BiometricFallbackAction {
  /// Prompt succeeded: unlock the app.
  enterApp,

  /// A plain mismatch — let the user try the biometric prompt again.
  retryBiometric,

  /// Biometric can't be used right now (cancelled/error/not available) and
  /// the account is email/password: fall back to re-entering the app
  /// password (spec 1.2 — "失敗時はパスワード／PIN入力にフォールバック").
  reenterPassword,

  /// Same as above but the account has no app password (Apple/Google),
  /// so the only fallback is to redo that provider's sign-in flow.
  reauthenticateWithProvider,
}

/// Pure branching logic split out of the UI so the fallback rules from spec
/// 1.2/1.4 can be unit tested without touching local_auth or Firebase.
class BiometricFallbackResolver {
  const BiometricFallbackResolver();

  BiometricFallbackAction resolve({
    required BiometricPromptResult result,
    required AuthProviderType provider,
  }) {
    switch (result) {
      case BiometricPromptResult.success:
        return BiometricFallbackAction.enterApp;
      case BiometricPromptResult.failed:
        return BiometricFallbackAction.retryBiometric;
      case BiometricPromptResult.cancelled:
      case BiometricPromptResult.error:
      case BiometricPromptResult.notAvailable:
        return provider == AuthProviderType.email
            ? BiometricFallbackAction.reenterPassword
            : BiometricFallbackAction.reauthenticateWithProvider;
    }
  }
}
