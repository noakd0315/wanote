import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/billing/domain/ad_policy.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';

void main() {
  group('AdPolicy', () {
    test('premium active: banner hidden and interstitial suppressed', () {
      const policy = AdPolicy(EntitlementState.active);

      expect(policy.shouldShowAds, isFalse);
      expect(policy.shouldShowBanner, isFalse);
      expect(policy.shouldShowInterstitial, isFalse);
    });

    test('premium inactive (confirmed free user): ads shown', () {
      const policy = AdPolicy(EntitlementState.inactive);

      expect(policy.shouldShowAds, isTrue);
      expect(policy.shouldShowBanner, isTrue);
      expect(policy.shouldShowInterstitial, isTrue);
    });

    test(
      'premium status unknown/loading: ads are hidden until non-premium is '
      'confirmed (never flash an ad at a premium user during the loading '
      'window)',
      () {
        const policy = AdPolicy(EntitlementState.unknown);

        expect(policy.shouldShowAds, isFalse);
        expect(policy.shouldShowBanner, isFalse);
        expect(policy.shouldShowInterstitial, isFalse);
      },
    );

    test('fromStatus maps PremiumStatus into the same decision', () {
      expect(
        AdPolicy.fromStatus(PremiumStatus.active).shouldShowAds,
        isFalse,
      );
      expect(
        AdPolicy.fromStatus(PremiumStatus.inactive).shouldShowAds,
        isTrue,
      );
      expect(
        AdPolicy.fromStatus(PremiumStatus.unknown).shouldShowAds,
        isFalse,
      );
    });
  });
}
