import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/ai/domain/usage_limit_policy.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

class MockAiUsageRepository extends Mock implements AiUsageRepository {}

void main() {
  const policy = UsageLimitPolicy();
  late MockAiUsageRepository repository;

  setUp(() {
    repository = MockAiUsageRepository();
  });

  group('decide (pure)', () {
    test('allows when free monthly quota remains', () {
      const status = AiUsageStatus(
        freeConsultationsRemainingThisMonth: 2,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: false,
      );
      expect(policy.decide(status), UsageLimitDecision.allow);
    });

    test('allows when free quota is exhausted but tickets remain', () {
      const status = AiUsageStatus(
        freeConsultationsRemainingThisMonth: 0,
        ticketsRemaining: 3,
        hasUnlimitedSubscription: false,
      );
      expect(policy.decide(status), UsageLimitDecision.allow);
    });

    test('requires upgrade when free quota and tickets are both exhausted', () {
      const status = AiUsageStatus(
        freeConsultationsRemainingThisMonth: 0,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: false,
      );
      expect(policy.decide(status), UsageLimitDecision.requireUpgrade);
    });

    test(
      'allows unlimited subscribers even with no free/ticket quota left',
      () {
        const status = AiUsageStatus(
          freeConsultationsRemainingThisMonth: 0,
          ticketsRemaining: 0,
          hasUnlimitedSubscription: true,
        );
        expect(policy.decide(status), UsageLimitDecision.allow);
      },
    );
  });

  group('decideForUser (against a fake AiUsageRepository)', () {
    test(
      'fetches status from the repository and allows when quota remains',
      () async {
        const status = AiUsageStatus(
          freeConsultationsRemainingThisMonth: 1,
          ticketsRemaining: 0,
          hasUnlimitedSubscription: false,
        );
        when(
          () => repository.getStatus('uid-1'),
        ).thenAnswer((_) async => status);

        final decision = await policy.decideForUser(repository, 'uid-1');

        expect(decision, UsageLimitDecision.allow);
        verify(() => repository.getStatus('uid-1')).called(1);
      },
    );

    test(
      'requires upgrade when the repository reports exhausted usage',
      () async {
        const status = AiUsageStatus(
          freeConsultationsRemainingThisMonth: 0,
          ticketsRemaining: 0,
          hasUnlimitedSubscription: false,
        );
        when(
          () => repository.getStatus('uid-2'),
        ).thenAnswer((_) async => status);

        final decision = await policy.decideForUser(repository, 'uid-2');

        expect(decision, UsageLimitDecision.requireUpgrade);
      },
    );

    test('allows unlimited subscribers reported by the repository', () async {
      const status = AiUsageStatus(
        freeConsultationsRemainingThisMonth: 0,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: true,
      );
      when(() => repository.getStatus('uid-3')).thenAnswer((_) async => status);

      final decision = await policy.decideForUser(repository, 'uid-3');

      expect(decision, UsageLimitDecision.allow);
    });
  });
}
