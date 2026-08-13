import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/billing/domain/ad_trigger.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

/// Which actions show an ad.
///
/// The load-bearing rule is the ticket exemption. Someone who bought an AI
/// ticket pack without subscribing has already paid for that call; making
/// them watch an ad for it charges them twice for one thing. Nothing in the
/// UI would reveal the mistake -- the ad would simply appear, and look
/// exactly like the intended behaviour.
void main() {
  const policy = AdTriggerPolicy();

  const premium = PremiumStatus.active;
  const free = PremiumStatus.inactive;
  const unknown = PremiumStatus.unknown;

  bool showsFor(
    AdTrigger trigger, {
    PremiumStatus status = free,
    AiUsageSource? source,
  }) => policy.shouldShowAd(
    trigger: trigger,
    premiumStatus: status,
    aiUsageSource: source,
  );

  group('the ticket exemption', () {
    test('an AI call paid for with a ticket shows no ad', () {
      expect(
        showsFor(AdTrigger.aiConsultation, source: AiUsageSource.ticket),
        isFalse,
      );
      expect(
        showsFor(AdTrigger.aiFoodPortion, source: AiUsageSource.ticket),
        isFalse,
      );
    });

    test('an AI call on the free monthly allowance still shows one', () {
      // The free allowance is what ads pay for. This is the case the whole
      // ad mechanism exists to cover.
      expect(
        showsFor(AdTrigger.aiConsultation, source: AiUsageSource.freeQuota),
        isTrue,
      );
    });

    test('a photo upload is unaffected by a ticket balance', () {
      // Tickets are sold as AI相談チケット and only AI calls consume them.
      // The upload triggers pass no source at all.
      expect(showsFor(AdTrigger.healthRecordUpload), isTrue);
      expect(showsFor(AdTrigger.toiletRecordUpload), isTrue);
    });

    test('the certificate scan is unaffected too', () {
      // OCR is rate-limited server-side rather than paid for with tickets
      // (PM decision, 2026-08-12), so a ticket balance does not exempt it.
      expect(showsFor(AdTrigger.certificateCapture), isTrue);
    });
  });

  group('subscription', () {
    test('a subscriber sees no ad anywhere', () {
      for (final trigger in AdTrigger.values) {
        expect(
          showsFor(
            trigger,
            status: premium,
            source: AiUsageSource.subscription,
          ),
          isFalse,
          reason: '$trigger showed an ad to a subscriber',
        );
      }
    });

    test('nothing shows while the subscription is still unconfirmed', () {
      // RevenueCat has not answered yet. Showing an ad now and hiding it a
      // moment later would flash one at a paying subscriber.
      for (final trigger in AdTrigger.values) {
        expect(showsFor(trigger, status: unknown), isFalse, reason: '$trigger');
      }
    });
  });

  test('a free user with no source information still sees ads', () {
    // Defensive: a trigger that forgets to pass the source must not
    // accidentally become ad-free for everyone.
    expect(showsFor(AdTrigger.aiConsultation), isTrue);
  });
}
