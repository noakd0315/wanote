import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';
import 'package:wanote/features/billing/domain/product_ids.dart';
import 'package:wanote/features/billing/domain/purchase_event_handler.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

class _MockAiUsageRepository extends Mock implements AiUsageRepository {}

void main() {
  late _MockAiUsageRepository aiUsageRepository;
  late PurchaseEventHandler handler;

  const uid = 'user-123';

  setUp(() {
    aiUsageRepository = _MockAiUsageRepository();
    handler = PurchaseEventHandler(aiUsageRepository: aiUsageRepository);

    // Stub every method mocktail might be asked to verify, with permissive
    // default returns, so unrelated calls in a test don't throw MissingStub.
    when(
      () => aiUsageRepository.creditTickets(
        any(),
        any(),
        transactionId: any(named: 'transactionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => aiUsageRepository.setUnlimitedSubscription(any(), any()),
    ).thenAnswer((_) async {});
  });

  group('PurchaseEventHandler', () {
    test('ai_tickets_5 purchase credits 5 tickets', () async {
      await handler.handle(
        uid: uid,
        event: const ConsumableProductPurchased(ProductIds.aiTickets5, 'txn-1'),
      );

      verify(
        () => aiUsageRepository.creditTickets(uid, 5, transactionId: 'txn-1'),
      ).called(1);
      verifyNever(
        () => aiUsageRepository.creditTickets(uid, 15, transactionId: 'txn-1'),
      );
      verifyNever(
        () => aiUsageRepository.setUnlimitedSubscription(any(), any()),
      );
    });

    test('ai_tickets_15 purchase credits 15 tickets', () async {
      await handler.handle(
        uid: uid,
        event: const ConsumableProductPurchased(
          ProductIds.aiTickets15,
          'txn-1',
        ),
      );

      verify(
        () => aiUsageRepository.creditTickets(uid, 15, transactionId: 'txn-1'),
      ).called(1);
      verifyNever(
        () => aiUsageRepository.creditTickets(uid, 5, transactionId: 'txn-1'),
      );
      verifyNever(
        () => aiUsageRepository.setUnlimitedSubscription(any(), any()),
      );
    });

    test(
      'premium entitlement becoming active sets unlimited subscription true',
      () async {
        await handler.handle(
          uid: uid,
          event: const EntitlementStateChanged(
            entitlementId: EntitlementIds.premium,
            isActive: true,
          ),
        );

        verify(
          () => aiUsageRepository.setUnlimitedSubscription(uid, true),
        ).called(1);
        verifyNever(
          () => aiUsageRepository.creditTickets(
            any(),
            any(),
            transactionId: any(named: 'transactionId'),
          ),
        );
      },
    );

    test(
      'premium entitlement becoming inactive sets unlimited subscription false',
      () async {
        await handler.handle(
          uid: uid,
          event: const EntitlementStateChanged(
            entitlementId: EntitlementIds.premium,
            isActive: false,
          ),
        );

        verify(
          () => aiUsageRepository.setUnlimitedSubscription(uid, false),
        ).called(1);
        verifyNever(
          () => aiUsageRepository.creditTickets(
            any(),
            any(),
            transactionId: any(named: 'transactionId'),
          ),
        );
      },
    );

    test(
      'unrecognized product id is a no-op: does not throw, does not call the repository',
      () async {
        await handler.handle(
          uid: uid,
          event: const ConsumableProductPurchased('some_future_sku', 'txn-1'),
        );

        verifyNever(
          () => aiUsageRepository.creditTickets(
            any(),
            any(),
            transactionId: any(named: 'transactionId'),
          ),
        );
        verifyNever(
          () => aiUsageRepository.setUnlimitedSubscription(any(), any()),
        );
      },
    );

    test(
      'entitlement id other than "premium" is a no-op: does not throw, does not call the repository',
      () async {
        await handler.handle(
          uid: uid,
          event: const EntitlementStateChanged(
            entitlementId: 'some_other_entitlement',
            isActive: true,
          ),
        );

        verifyNever(
          () => aiUsageRepository.setUnlimitedSubscription(any(), any()),
        );
        verifyNever(
          () => aiUsageRepository.creditTickets(
            any(),
            any(),
            transactionId: any(named: 'transactionId'),
          ),
        );
      },
    );
  });
}
