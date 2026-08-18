import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wanote/features/billing/ads/ad_gate.dart';
import 'package:wanote/features/billing/ads/ad_manager.dart';
import 'package:wanote/features/billing/domain/ad_trigger.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

class MockAdManager extends Mock implements AdManager {}

/// The one object screens talk to about ads.
void main() {
  late MockAdManager manager;

  setUp(() {
    manager = MockAdManager();
    when(manager.maybeShowInterstitial).thenAnswer((_) async => true);
    when(manager.preloadInterstitial).thenAnswer((_) async {});
  });

  AdGate buildGate({PremiumStatus status = PremiumStatus.inactive}) =>
      AdGate(manager: manager, premiumStatus: () => status);

  test('shows an ad for a free user', () async {
    await buildGate().maybeShow(AdTrigger.healthRecordUpload);

    verify(manager.maybeShowInterstitial).called(1);
  });

  test('shows nothing to a subscriber', () async {
    await buildGate(
      status: PremiumStatus.active,
    ).maybeShow(AdTrigger.healthRecordUpload);

    verifyNever(manager.maybeShowInterstitial);
  });

  test('shows nothing for an AI call a ticket paid for', () async {
    await buildGate().maybeShow(
      AdTrigger.aiConsultation,
      aiUsageSource: AiUsageSource.ticket,
    );

    verifyNever(manager.maybeShowInterstitial);
  });

  test('reads the premium status fresh on every call', () async {
    // RevenueCat answers asynchronously after launch. A status captured
    // once at construction would be `unknown` forever, and ads would never
    // appear at all.
    var status = PremiumStatus.unknown;
    final gate = AdGate(manager: manager, premiumStatus: () => status);

    await gate.maybeShow(AdTrigger.healthRecordUpload);
    verifyNever(manager.maybeShowInterstitial);

    status = PremiumStatus.inactive;
    await gate.maybeShow(AdTrigger.healthRecordUpload);
    verify(manager.maybeShowInterstitial).called(1);
  });

  test('a failing ad network never surfaces to the caller', () async {
    // Every call site sits right after something the owner wanted -- a
    // saved record, an AI answer. An exception here would make that action
    // look like it failed.
    when(manager.maybeShowInterstitial).thenThrow(Exception('no fill'));

    await expectLater(
      buildGate().maybeShow(AdTrigger.toiletRecordUpload),
      completes,
    );
  });

  group('adGateOf', () {
    testWidgets('finds the gate provided by the app shell', (tester) async {
      final gate = buildGate();
      AdGate? found;

      await tester.pumpWidget(
        Provider<AdGate>.value(
          value: gate,
          child: Builder(
            builder: (context) {
              found = adGateOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(found, same(gate));
    });

    testWidgets('returns null instead of throwing when there is none', (
      tester,
    ) async {
      // Screens are also built in widget tests and reached from the launch
      // gate, neither of which sits under the shell's provider. A missing
      // ad gate must mean "no ads", not a crash on a screen someone is
      // trying to use.
      AdGate? found = buildGate();

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = adGateOf(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(found, isNull);
    });
  });

  // PM, 2026-08-18: the certificate scan showed no ad on iOS. Presentation
  // there is refused while the screen is still finishing a transition, and
  // a lost impression is invisible -- so nothing would ever have reported
  // it. The reasons are momentary, so one more attempt is usually enough.
  group('a presentation that did not reach the screen', () {
    test('is attempted once more', () async {
      when(manager.maybeShowInterstitial).thenAnswer((_) async => false);

      await buildGate().maybeShow(AdTrigger.certificateCapture);

      verify(manager.maybeShowInterstitial).called(2);
    });

    test('is not retried when the first attempt succeeded', () async {
      await buildGate().maybeShow(AdTrigger.certificateCapture);

      verify(manager.maybeShowInterstitial).called(1);
    });

    test('retries at most once, however many times it fails', () async {
      when(manager.maybeShowInterstitial).thenAnswer((_) async => false);

      await buildGate().maybeShow(AdTrigger.certificateCapture);

      // A loop here would turn a dead ad network into a retry storm.
      verify(manager.maybeShowInterstitial).called(2);
    });

    test('a premium user is not retried at either step', () async {
      when(manager.maybeShowInterstitial).thenAnswer((_) async => false);

      await buildGate(
        status: PremiumStatus.active,
      ).maybeShow(AdTrigger.certificateCapture);

      verifyNever(manager.maybeShowInterstitial);
    });
  });
}
