import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wanote/features/ai/data/ai_backend_client.dart';
import 'package:wanote/features/ai/data/consultation_repository.dart';
import 'package:wanote/features/ai/models/consultation.dart';
import 'package:wanote/features/ai/presentation/consultation_screen.dart';
import 'package:wanote/features/billing/ads/ad_gate.dart';
import 'package:wanote/features/billing/ads/ad_manager.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

class MockAiBackendClient extends Mock implements AiBackendClient {}

class MockConsultationRepository extends Mock
    implements ConsultationRepository {}

class MockAdManager extends Mock implements AdManager {}

/// A retry after a failed consultation must not cost a second ad.
///
/// The ad and the request are started together so the ad covers the wait,
/// which means a request that then fails has already spent its impression.
/// Nothing can take that one back -- but making the owner sit through
/// another one to ask the same question again is charging twice for one
/// consultation, and the failure was not theirs (PM report, 2026-08-15).
///
/// This is a test about a count rather than an outcome: an ad plays either
/// way, so a regression here would look correct in the running app until
/// someone happened to retry.
class _StubUsageRepository implements AiUsageRepository {
  int recordedUses = 0;

  @override
  Future<AiUsageStatus> getStatus(String uid) async => const AiUsageStatus(
    freeConsultationsRemainingThisMonth: 5,
    ticketsRemaining: 0,
    hasUnlimitedSubscription: false,
  );

  @override
  Future<void> recordConsultationUsed(String uid) async => recordedUses++;

  @override
  Future<void> creditTickets(String uid, int count) async {}

  @override
  Future<void> setUnlimitedSubscription(String uid, bool active) async {}
}

void main() {
  late MockAiBackendClient backend;
  late MockConsultationRepository consultations;
  late MockAdManager adManager;
  late _StubUsageRepository usage;
  late int adsShown;

  setUp(() {
    backend = MockAiBackendClient();
    consultations = MockConsultationRepository();
    adManager = MockAdManager();
    usage = _StubUsageRepository();
    adsShown = 0;

    when(adManager.maybeShowInterstitial).thenAnswer((_) async {
      adsShown++;
    });
    when(adManager.preloadInterstitial).thenAnswer((_) async {});
    // The screen renders a history list under the form; without this the
    // build throws before any of the ad behaviour is reached.
    when(
      () => consultations.watchHistory(any(), any()),
    ).thenAnswer((_) => Stream<List<Consultation>>.value(const []));
    when(
      () => consultations.save(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        questionText: any(named: 'questionText'),
        aiResponse: any(named: 'aiResponse'),
        referencedRecordIds: any(named: 'referencedRecordIds'),
      ),
    ).thenAnswer(
      (_) async => Consultation(
        consultationId: 'c1',
        petId: 'pet-1',
        questionText: 'q',
        aiResponse: 'a',
        createdAt: DateTime(2026, 8, 15),
      ),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      Provider<AdGate>.value(
        value: AdGate(
          manager: adManager,
          premiumStatus: () => PremiumStatus.inactive,
        ),
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ConsultationScreen(
            uid: 'uid-1',
            petId: 'pet-1',
            usageRepository: usage,
            backendClient: backend,
            consultationRepository: consultations,
            onRequestUpgrade: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Types a question with no emergency keyword in it -- one that trips the
  /// client-side detector never reaches the backend at all.
  Future<void> ask(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'ごはんを残しています');
    await tester.pumpAndSettle();
    final send = find.byType(FilledButton).first;
    await tester.scrollUntilVisible(
      send,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
  }

  testWidgets('a retry after a failed consultation shows no second ad', (
    tester,
  ) async {
    var attempt = 0;
    when(
      () => backend.requestConsultation(
        petId: any(named: 'petId'),
        questionText: any(named: 'questionText'),
        referencedRecords: any(named: 'referencedRecords'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async {
      attempt++;
      if (attempt == 1) throw AiBackendException(statusCode: 500, message: 'boom');
      return '様子を見てください。';
    });

    await pumpScreen(tester);
    await ask(tester);
    expect(adsShown, 1, reason: 'the first attempt spends the impression');

    await ask(tester);

    expect(attempt, 2, reason: 'the retry really did reach the backend');
    expect(adsShown, 1, reason: 'the retry must not cost a second ad');
    expect(usage.recordedUses, 1, reason: 'only the successful call counts');
  });
}
