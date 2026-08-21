import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/auth/domain/auth_gate_resolver.dart';

void main() {
  group('AuthGateResolver', () {
    const resolver = AuthGateResolver();

    test('no active session -> requireSignIn regardless of other flags', () {
      expect(
        resolver.resolve(
          hasActiveSession: false,
          biometricEnabled: false,
          biometricAvailable: false,
        ),
        AuthGateAction.requireSignIn,
      );
      expect(
        resolver.resolve(
          hasActiveSession: false,
          biometricEnabled: true,
          biometricAvailable: true,
        ),
        AuthGateAction.requireSignIn,
      );
    });

    // Biometrics replace signing in again; they are not an extra step on
    // top of a session that is still valid. Asking whenever they were
    // enabled started a scan on the way to Home right after a password had
    // just been typed (PM report, 2026-08-21).
    test('live session, biometric enabled and available -> enterApp', () {
      expect(
        resolver.resolve(
          hasActiveSession: true,
          biometricEnabled: true,
          biometricAvailable: true,
        ),
        AuthGateAction.enterApp,
      );
    });

    test(
      'expired session, biometric enabled and available -> requireBiometric',
      () {
        expect(
          resolver.resolve(
            hasActiveSession: true,
            biometricEnabled: true,
            biometricAvailable: true,
            sessionExpired: true,
          ),
          AuthGateAction.requireBiometric,
        );
      },
    );

    // Locking is a deliberate "hide this until I prove it's me", so it wins
    // over a session that is still perfectly valid (PM, 2026-08-21).
    test('locked with biometrics available -> requireBiometric', () {
      expect(
        resolver.resolve(
          hasActiveSession: true,
          biometricEnabled: true,
          biometricAvailable: true,
          locked: true,
        ),
        AuthGateAction.requireBiometric,
      );
    });

    test('locked but the device has no biometrics -> enterApp', () {
      // A lock with no key would strand the owner. Only accounts with
      // biometrics set up are ever offered the lock in the first place, so
      // this is the case where they were removed afterwards.
      expect(
        resolver.resolve(
          hasActiveSession: true,
          biometricEnabled: true,
          biometricAvailable: false,
          locked: true,
        ),
        AuthGateAction.enterApp,
      );
    });

    test('expired session with no biometric to fall back on -> sign in', () {
      expect(
        resolver.resolve(
          hasActiveSession: true,
          biometricEnabled: true,
          biometricAvailable: false,
          sessionExpired: true,
        ),
        AuthGateAction.requireSignIn,
      );
    });

    test(
      'active session, biometric enabled but device unavailable -> enterApp',
      () {
        expect(
          resolver.resolve(
            hasActiveSession: true,
            biometricEnabled: true,
            biometricAvailable: false,
          ),
          AuthGateAction.enterApp,
        );
      },
    );

    test(
      'active session, biometric disabled, device available -> enterApp',
      () {
        expect(
          resolver.resolve(
            hasActiveSession: true,
            biometricEnabled: false,
            biometricAvailable: true,
          ),
          AuthGateAction.enterApp,
        );
      },
    );

    test(
      'active session, biometric disabled and device unavailable -> enterApp',
      () {
        expect(
          resolver.resolve(
            hasActiveSession: true,
            biometricEnabled: false,
            biometricAvailable: false,
          ),
          AuthGateAction.enterApp,
        );
      },
    );
  });
}
