import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/billing/data/billing_config.dart';
import 'package:wanote/features/billing/data/billing_repository.dart';

/// Opening the paywall in a build without a RevenueCat API key used to kill
/// the app on iPhone (PM report, 2026-08-17). RevenueCat's iOS SDK calls
/// `fatalError` when `Purchases.shared` is read before `configure()`, so the
/// failure never reaches Dart -- a `try`/`catch` around the call cannot save
/// it. The only fix is to not make the call.
///
/// These tests run unconfigured by construction: `BillingConfig` reads a
/// `--dart-define` that the test harness does not supply. If a future change
/// makes the guard depend on something else, the first expectation here
/// fails loudly rather than the suite quietly testing nothing.
void main() {
  test('the test environment has no RevenueCat key, as these tests assume', () {
    expect(BillingConfig.isConfigured, isFalse);
  });

  group('RevenueCatBillingRepository when RevenueCat is not configured', () {
    late RevenueCatBillingRepository repository;

    setUp(() => repository = RevenueCatBillingRepository());

    test('getOfferings reports it instead of reaching the SDK', () {
      expect(
        repository.getOfferings(),
        throwsA(isA<BillingNotConfiguredException>()),
      );
    });

    test('purchase reports it instead of reaching the SDK', () {
      expect(
        repository.purchase(r'$rc_monthly'),
        throwsA(isA<BillingNotConfiguredException>()),
      );
    });

    test('restorePurchases reports it instead of reaching the SDK', () {
      expect(
        repository.restorePurchases(),
        throwsA(isA<BillingNotConfiguredException>()),
      );
    });

    test('configure still no-ops rather than throwing', () {
      // configure() runs at app start for every user, long before anyone
      // opens the paywall. It must stay silent.
      expect(repository.configure(), completes);
    });
  });
}
