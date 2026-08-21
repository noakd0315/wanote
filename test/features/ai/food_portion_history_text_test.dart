import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/ai/data/ai_backend_client.dart';
import 'package:wanote/features/ai/data/consultation_repository.dart';
import 'package:wanote/features/ai/models/consultation.dart';
import 'package:wanote/features/ai/presentation/food_portion_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

class MockAiBackendClient extends Mock implements AiBackendClient {}

class MockConsultationRepository extends Mock
    implements ConsultationRepository {}

/// What the owner reads in their history is not what the model was sent.
///
/// The prompt is English, carries stored units, and ends with instructions
/// aimed at the model. It used to be saved verbatim, so the history showed
/// the owner our own prompt -- "Keep it brief" and all (PM report,
/// 2026-08-15). The two are now built separately, and this test exists to
/// keep them apart: reusing the prompt again would look like a tidy
/// simplification in a diff.
class _StubUsageRepository implements AiUsageRepository {
  @override
  Stream<AiUsageStatus> watchStatus(String uid) =>
      Stream<AiUsageStatus>.fromFuture(getStatus(uid));

  @override
  Future<AiUsageStatus> getStatus(String uid) async => const AiUsageStatus(
    freeConsultationsRemainingThisMonth: 5,
    ticketsRemaining: 0,
    hasUnlimitedSubscription: false,
  );

  @override
  Future<void> recordConsultationUsed(String uid) async {}

  @override
  Future<void> creditTickets(
    String uid,
    int count, {
    required String transactionId,
  }) async {}

  @override
  Future<void> setUnlimitedSubscription(String uid, bool active) async {}
}

void main() {
  late MockAiBackendClient backend;
  late MockConsultationRepository consultations;
  late String? sentPrompt;
  late String? storedText;

  setUp(() {
    backend = MockAiBackendClient();
    consultations = MockConsultationRepository();
    sentPrompt = null;
    storedText = null;

    when(
      () => backend.requestConsultation(
        petId: any(named: 'petId'),
        questionText: any(named: 'questionText'),
        referencedRecords: any(named: 'referencedRecords'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((invocation) async {
      sentPrompt = invocation.namedArguments[#questionText] as String;
      return '1日2回に分けてください。';
    });

    when(
      () => consultations.save(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        questionText: any(named: 'questionText'),
        aiResponse: any(named: 'aiResponse'),
        referencedRecordIds: any(named: 'referencedRecordIds'),
      ),
    ).thenAnswer((invocation) async {
      storedText = invocation.namedArguments[#questionText] as String;
      return Consultation(
        consultationId: 'c1',
        petId: 'pet-1',
        questionText: storedText!,
        aiResponse: 'a',
        createdAt: DateTime(2026, 8, 15),
      );
    });
  });

  testWidgets('the history entry is Japanese, and is not the prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FoodPortionScreen(
          uid: 'uid-1',
          petId: 'pet-1',
          birthday: DateTime(2022, 5, 1),
          neutered: true,
          usageRepository: _StubUsageRepository(),
          backendClient: backend,
          consultationRepository: consultations,
          onRequestUpgrade: () {},
          initialWeightKg: 5.0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drive the screen the way the owner does: fill the food density, then
    // ask. Everything else has a usable default or is prefilled.
    await tester.enterText(
      find.widgetWithText(TextField, 'フードのカロリー密度 (kcal/100g)'),
      '350',
    );
    await tester.pumpAndSettle();

    // Two steps, as on the screen: calculate the portion, then ask about it.
    // The advice button does not exist until there is a result.
    final calculate = find.text('計算する');
    await tester.scrollUntilVisible(
      calculate,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    final ask = find.text('AIに給餌のアドバイスを聞く');
    await tester.scrollUntilVisible(
      ask,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(ask);
    await tester.pumpAndSettle();

    expect(sentPrompt, isNotNull, reason: 'the backend was actually called');
    expect(storedText, isNotNull, reason: 'the advice was actually saved');

    // The prompt still says what it always said.
    expect(sentPrompt, contains('Keep it brief'));

    // The history says none of it.
    expect(storedText, isNot(contains('Keep it brief')));
    expect(storedText, isNot(contains('How should this')));
    expect(storedText, isNot(contains('body condition')));
    expect(storedText, contains('【餌の量】'));
    expect(storedText, contains('体重'));
  });
}
