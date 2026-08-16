import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/daily_record/data/health_record_repository.dart';
import 'package:wanote/features/daily_record/data/toilet_record_repository.dart';
import 'package:wanote/features/daily_record/models/toilet_record.dart';
import 'package:wanote/features/daily_record/presentation/toilet_record_timeline_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

class MockToiletRecordRepository extends Mock
    implements ToiletRecordRepository {}

class MockHealthRecordRepository extends Mock
    implements HealthRecordRepository {}

/// A noticed anomaly offers a consultation; it does not start one.
///
/// The callback used to fire straight off the record stream, and the shell
/// turned that into a pushed screen -- so one bloody-stool record on file
/// meant the AI consultation screen opened itself over the home screen on
/// every launch and every sign-in (PM report, 2026-08-16). The sections
/// live in an IndexedStack, so this screen's stream runs whether or not its
/// tab is the one being looked at.
///
/// The distinction is invisible in a diff -- both versions "call the
/// callback when something is detected" -- which is why it is pinned here.
void main() {
  late MockToiletRecordRepository repository;
  late MockHealthRecordRepository healthRecordRepository;
  late List<Object> suggestions;

  setUp(() {
    repository = MockToiletRecordRepository();
    healthRecordRepository = MockHealthRecordRepository();
    suggestions = [];

    when(() => repository.watchTimeline(any(), any())).thenAnswer(
      (_) => Stream.value([
        ToiletRecord(
          toiletId: 'r1',
          petId: 'pet-1',
          type: ToiletType.stool,
          recordedAt: DateTime.now(),
          stoolCondition: const StoolCondition(
            hardness: StoolHardness.normal,
            color: StoolColor.bloodSuspected,
          ),
        ),
      ]),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ToiletRecordTimelineScreen(
          uid: 'uid-1',
          petId: 'pet-1',
          repository: repository,
          healthRecordRepository: healthRecordRepository,
          onConsultationSuggested: (s) => suggestions.add(s),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a bloody-stool record raises the banner and nothing else', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.byType(MaterialBanner),
      findsOneWidget,
      reason: 'the owner is told what was noticed',
    );
    expect(
      suggestions,
      isEmpty,
      reason:
          'and is left to decide. Firing here is what opened the AI screen '
          'over the home screen on every launch.',
    );
  });

  testWidgets('the banner button is what asks for a consultation', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('AI相談する'));
    await tester.pumpAndSettle();

    expect(suggestions, hasLength(1));
  });
}
