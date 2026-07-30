import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/auth/data/biometric_service.dart';
import 'package:wanote/features/auth/domain/biometric_fallback_resolver.dart';
import 'package:wanote/shared/models/auth_provider_type.dart';

void main() {
  group('BiometricFallbackResolver', () {
    const resolver = BiometricFallbackResolver();

    test('success -> enterApp regardless of provider', () {
      for (final provider in AuthProviderType.values) {
        expect(
          resolver.resolve(
            result: BiometricPromptResult.success,
            provider: provider,
          ),
          BiometricFallbackAction.enterApp,
          reason: 'provider: $provider',
        );
      }
    });

    test('failed -> retryBiometric regardless of provider', () {
      for (final provider in AuthProviderType.values) {
        expect(
          resolver.resolve(
            result: BiometricPromptResult.failed,
            provider: provider,
          ),
          BiometricFallbackAction.retryBiometric,
          reason: 'provider: $provider',
        );
      }
    });

    for (final result in [
      BiometricPromptResult.cancelled,
      BiometricPromptResult.error,
      BiometricPromptResult.notAvailable,
    ]) {
      test(
        '$result + email provider -> reenterPassword',
        () {
          expect(
            resolver.resolve(result: result, provider: AuthProviderType.email),
            BiometricFallbackAction.reenterPassword,
          );
        },
      );

      test(
        '$result + google provider -> reauthenticateWithProvider',
        () {
          expect(
            resolver.resolve(result: result, provider: AuthProviderType.google),
            BiometricFallbackAction.reauthenticateWithProvider,
          );
        },
      );

      test(
        '$result + apple provider -> reauthenticateWithProvider',
        () {
          expect(
            resolver.resolve(result: result, provider: AuthProviderType.apple),
            BiometricFallbackAction.reauthenticateWithProvider,
          );
        },
      );
    }
  });
}
