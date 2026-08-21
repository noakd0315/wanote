import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/billing/ads/ad_preparer.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';

void main() {
  group('prepareAds', () {
    late StreamController<PremiumStatus> statusController;
    late PremiumStatus current;
    late int preloadCount;

    setUp(() {
      // Broadcast, like the real repository. A single-subscription stream
      // would buffer the very event this test is about and hide the bug.
      statusController = StreamController<PremiumStatus>.broadcast();
      current = PremiumStatus.unknown;
      preloadCount = 0;
    });

    tearDown(() => statusController.close());

    Future<void> run({
      required Future<void> Function() initializeSdk,
      Duration timeout = const Duration(seconds: 10),
    }) => prepareAds(
      initializeSdk: initializeSdk,
      premiumStatusChanges: statusController.stream,
      currentPremiumStatus: () => current,
      preload: () async => preloadCount++,
      timeout: timeout,
    );

    void report(PremiumStatus status) {
      current = status;
      statusController.add(status);
    }

    test(
      'preloads when the status is reported while the SDK is still starting',
      () async {
        // The device failure, reduced: billing answers immediately because
        // there is no RevenueCat key, while the ads SDK takes its time. Any
        // subscription made after initializeSdk misses that answer entirely,
        // waits out the timeout, and never preloads -- which is why no ad
        // appeared anywhere in the app.
        final sdkStarted = Completer<void>();
        final sdkFinished = Completer<void>();

        final pending = run(
          initializeSdk: () {
            sdkStarted.complete();
            return sdkFinished.future;
          },
          timeout: const Duration(milliseconds: 50),
        );

        await sdkStarted.future;
        report(PremiumStatus.inactive);
        sdkFinished.complete();
        await pending;

        expect(preloadCount, 1);
      },
    );

    test('preloads when the status arrives after the SDK is up', () async {
      final pending = run(initializeSdk: () async {});
      await Future<void>.delayed(Duration.zero);
      expect(preloadCount, 0, reason: 'must wait for a confirmed status');

      report(PremiumStatus.inactive);
      await pending;

      expect(preloadCount, 1);
    });

    test(
      'preloads for subscribers too; the policy decides, not this',
      () async {
        final pending = run(initializeSdk: () async {});
        report(PremiumStatus.active);
        await pending;

        expect(preloadCount, 1);
      },
    );

    test('gives up quietly when no status ever arrives', () async {
      await run(
        initializeSdk: () async {},
        timeout: const Duration(milliseconds: 20),
      );

      expect(preloadCount, 0);
    });

    test('a failing SDK costs ads, not the session', () async {
      await expectLater(
        run(initializeSdk: () async => throw StateError('no ads today')),
        completes,
      );

      expect(preloadCount, 0);
    });

    test('fetches again when the plan lapses mid-session', () async {
      // The report that started this: a free month that was still running
      // when the app opened, so nothing was fetched, and had run out by the
      // time the entitlement was re-read. No ad appeared for the rest of
      // that session while the free allowance was being spent (PM,
      // 2026-08-21).
      current = PremiumStatus.active;
      await run(initializeSdk: () async {});
      expect(preloadCount, 1);

      report(PremiumStatus.inactive);
      await Future<void>.delayed(Duration.zero);

      expect(preloadCount, 2);
    });

    test('does not fetch while the account is still premium', () async {
      current = PremiumStatus.inactive;
      await run(initializeSdk: () async {});
      expect(preloadCount, 1);

      // Someone subscribing mid-session. An ad must not be waiting for them.
      report(PremiumStatus.active);
      await Future<void>.delayed(Duration.zero);

      expect(preloadCount, 1);
    });

    test('the subscription stops fetching once cancelled', () async {
      current = PremiumStatus.inactive;
      final refills = await prepareAds(
        initializeSdk: () async {},
        premiumStatusChanges: statusController.stream,
        currentPremiumStatus: () => current,
        preload: () async => preloadCount++,
      );
      await refills.cancel();

      report(PremiumStatus.inactive);
      await Future<void>.delayed(Duration.zero);

      expect(preloadCount, 1);
    });

    test(
      'reports no unhandled error once the status is already known',
      () async {
        // The status is known before the wait, so the timeout future is left
        // over. Unretired, it would fire into the zone as an unhandled error
        // long after prepareAds returned.
        final errors = <Object>[];
        await runZonedGuarded(() async {
          current = PremiumStatus.inactive;
          await run(
            initializeSdk: () async {},
            timeout: const Duration(milliseconds: 10),
          );
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }, (error, _) => errors.add(error));

        expect(preloadCount, 1);
        expect(errors, isEmpty);
      },
    );
  });
}
