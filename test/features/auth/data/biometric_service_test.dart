import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/auth/data/biometric_service.dart';

/// Pins the local_auth 3.x call shape. The upgrade flattened
/// AuthenticationOptions into named arguments and renamed stickyAuth to
/// persistAcrossBackgrounding; both are pass/fail signals the compiler
/// cannot check for us, and getting either wrong silently changes how the
/// OS prompt behaves (spec 1.2's PIN/passcode fallback).
class _MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  late _MockLocalAuth localAuth;
  late LocalAuthBiometricService service;

  setUp(() {
    localAuth = _MockLocalAuth();
    service = LocalAuthBiometricService(localAuth: localAuth);
  });

  void stubAvailable({bool supported = true, bool canCheck = true}) {
    when(
      () => localAuth.isDeviceSupported(),
    ).thenAnswer((_) async => supported);
    when(() => localAuth.canCheckBiometrics).thenAnswer((_) async => canCheck);
  }

  test(
    'reports unavailable when the device has no usable biometrics',
    () async {
      stubAvailable(supported: false);
      expect(await service.isAvailable(), isFalse);
      expect(
        await service.authenticate(reason: 'r'),
        BiometricPromptResult.notAvailable,
      );
      verifyNever(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
        ),
      );
    },
  );

  test('asks the OS to allow its own PIN/passcode fallback', () async {
    stubAvailable();
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenAnswer((_) async => true);

    final result = await service.authenticate(reason: 'unlock wanote');

    expect(result, BiometricPromptResult.success);
    final call = verify(
      () => localAuth.authenticate(
        localizedReason: captureAny(named: 'localizedReason'),
        biometricOnly: captureAny(named: 'biometricOnly'),
        persistAcrossBackgrounding: captureAny(
          named: 'persistAcrossBackgrounding',
        ),
      ),
    )..called(1);
    final captured = call.captured;
    expect(captured[0], 'unlock wanote');
    expect(
      captured[1],
      isFalse,
      reason:
          'biometricOnly must stay false so the OS can fall back to '
          'device credentials (spec 1.2).',
    );
    expect(captured[2], isTrue, reason: 'Prompt must survive backgrounding.');
  });

  test('a non-matching biometric is a failure, not an error', () async {
    stubAvailable();
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenAnswer((_) async => false);

    expect(
      await service.authenticate(reason: 'r'),
      BiometricPromptResult.failed,
    );
  });

  test('a platform exception degrades to error rather than throwing', () async {
    stubAvailable();
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenThrow(Exception('lockout'));

    expect(
      await service.authenticate(reason: 'r'),
      BiometricPromptResult.error,
    );
  });
}
