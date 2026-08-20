import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/billing/domain/product_ids.dart';

void main() {
  group('ProductIds.baseId', () {
    // The identifiers the two stores actually returned once the products
    // were imported into RevenueCat (PM, 2026-08-20). Play appends the base
    // plan; Apple does not.
    test('strips Play\'s base-plan suffix from a subscription', () {
      expect(ProductIds.baseId('premium_monthly:monthly'), 'premium_monthly');
      expect(ProductIds.baseId('premium_yearly:yearly'), 'premium_yearly');
    });

    test('leaves an Apple identifier untouched', () {
      expect(ProductIds.baseId('premium_monthly'), 'premium_monthly');
      expect(ProductIds.baseId('ai_tickets_5'), 'ai_tickets_5');
    });

    test('would survive Play appending a purchase option to a ticket', () {
      // Tickets carry no suffix today, but one-time products gained their
      // own purchase-option layer in 2026. If Play ever starts appending it,
      // crediting must keep working -- the owner would otherwise pay and
      // receive nothing.
      expect(ProductIds.baseId('ai_tickets_5:buy'), 'ai_tickets_5');
      expect(ProductIds.baseId('ai_tickets_15:buy'), 'ai_tickets_15');
    });

    test('normalised subscription ids match the configured constants', () {
      expect(
        ProductIds.subscriptions.contains(
          ProductIds.baseId('premium_monthly:monthly'),
        ),
        isTrue,
      );
    });

    test('normalised ticket ids are recognised as consumables', () {
      for (final raw in ['ai_tickets_5', 'ai_tickets_5:buy']) {
        expect(
          ProductIds.consumables.contains(ProductIds.baseId(raw)),
          isTrue,
          reason: '$raw should credit tickets',
        );
      }
    });

    test('a subscription is never mistaken for a consumable', () {
      expect(
        ProductIds.consumables.contains(
          ProductIds.baseId('premium_monthly:monthly'),
        ),
        isFalse,
      );
    });
  });
}
