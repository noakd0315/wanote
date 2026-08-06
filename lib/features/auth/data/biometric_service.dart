import 'package:local_auth/local_auth.dart';

/// Outcome of a single biometric prompt attempt.
enum BiometricPromptResult {
  success,

  /// Biometric ran but didn't match / user retried past the limit.
  failed,

  /// User dismissed the prompt, or the OS-level fallback (device
  /// PIN/pattern/passcode) also failed/was cancelled.
  cancelled,

  /// Platform exception (e.g. lockout, hardware error).
  error,

  /// Device has no usable biometric enrollment at all.
  notAvailable,
}

/// Wraps `local_auth` so the app never handles fingerprint/face data
/// directly — per spec 1.4, biometric material itself must never be stored
/// by the app or server. `local_auth` only returns a pass/fail signal from
/// the OS (iOS LocalAuthentication / Android BiometricPrompt); no biometric
/// template ever crosses into Dart code.
abstract class BiometricService {
  /// Whether the device has biometric hardware AND at least one biometric
  /// enrolled (or a device credential set up as fallback).
  Future<bool> isAvailable();

  Future<BiometricPromptResult> authenticate({required String reason});
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    final supported = await _localAuth.isDeviceSupported();
    final canCheck = await _localAuth.canCheckBiometrics;
    return supported && canCheck;
  }

  @override
  Future<BiometricPromptResult> authenticate({required String reason}) async {
    if (!await isAvailable()) {
      return BiometricPromptResult.notAvailable;
    }
    try {
      // local_auth 3 flattened AuthenticationOptions into named arguments,
      // and renamed stickyAuth -> persistAcrossBackgrounding.
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        // Allows the OS to fall back to the device's own PIN/pattern/
        // passcode when biometrics fail — this is the "パスワード／PIN
        // 入力へのフォールバック" from spec 1.2, handled entirely by the OS.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate
          ? BiometricPromptResult.success
          : BiometricPromptResult.failed;
    } on Exception {
      return BiometricPromptResult.error;
    }
  }
}
