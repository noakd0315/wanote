import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/daily_record/data/health_record_repository.dart';
import 'package:wanote/features/daily_record/data/toilet_record_repository.dart';
import 'package:wanote/features/daily_record/models/health_record.dart';
import 'package:wanote/features/daily_record/models/toilet_record.dart';
import 'package:wanote/features/daily_record/presentation/toilet_record_form_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

class MockToiletRecordRepository extends Mock
    implements ToiletRecordRepository {}

class MockHealthRecordRepository extends Mock
    implements HealthRecordRepository {}

class FakeStoolCondition extends Fake implements StoolCondition {}

/// The copy into the daily log is the owner's choice, not the app's.
///
/// PM decision: a toggle on the stool form, off by default. Most bowel
/// movements are unremarkable, and copying every one would bury the entries
/// made because something was actually wrong.
void main() {
  setUpAll(() {
    registerFallbackValue(FakeStoolCondition());
    registerFallbackValue(ToiletType.stool);
  });

  late MockToiletRecordRepository toiletRepository;
  late MockHealthRecordRepository healthRepository;

  setUp(() {
    toiletRepository = MockToiletRecordRepository();
    healthRepository = MockHealthRecordRepository();

    when(
      () => toiletRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        type: any(named: 'type'),
        stoolCondition: any(named: 'stoolCondition'),
        photoBytes: any(named: 'photoBytes'),
        recordedAt: any(named: 'recordedAt'),
        location: any(named: 'location'),
      ),
    ).thenAnswer(
      (_) async => ToiletRecord(
        toiletId: 't1',
        petId: 'pet-1',
        type: ToiletType.stool,
        recordedAt: DateTime(2026, 8, 14),
      ),
    );
    when(
      () => healthRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        recordedAt: any(named: 'recordedAt'),
        photoBytes: any(named: 'photoBytes'),
        tags: any(named: 'tags'),
        memo: any(named: 'memo'),
        linkedPhotoUrls: any(named: 'linkedPhotoUrls'),
      ),
    ).thenAnswer(
      (_) async => HealthRecord(
        recordId: 'r1',
        petId: 'pet-1',
        recordedAt: DateTime(2026, 8, 14),
        photos: const [],
        tags: const [],
      ),
    );
  });

  Future<void> pumpForm(WidgetTester tester) async {
    // The form is a ListView, so its save button is below the fold on the
    // default 800px test surface and never gets built -- a finder cannot tap
    // a widget that does not exist. A tall window puts the whole form on
    // screen at once.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ToiletRecordFormScreen(
          uid: 'uid-1',
          petId: 'pet-1',
          repository: toiletRepository,
          healthRecordRepository: healthRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saves without copying when the toggle is untouched', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => toiletRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        type: any(named: 'type'),
        stoolCondition: any(named: 'stoolCondition'),
        photoBytes: any(named: 'photoBytes'),
        recordedAt: any(named: 'recordedAt'),
        location: any(named: 'location'),
      ),
    ).called(1);
    verifyNever(
      () => healthRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        recordedAt: any(named: 'recordedAt'),
        photoBytes: any(named: 'photoBytes'),
        tags: any(named: 'tags'),
        memo: any(named: 'memo'),
        linkedPhotoUrls: any(named: 'linkedPhotoUrls'),
      ),
    );
  });

  testWidgets('copies without the photo, and tags what the owner chose', (
    tester,
  ) async {
    await pumpForm(tester);

    // Diarrhea and suspected blood: both are choices made on this form, so
    // the tags on the copy are mapped from them rather than inferred.
    await tester.tap(find.text('Diarrhea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blood suspected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => healthRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        recordedAt: any(named: 'recordedAt'),
        photoBytes: captureAny(named: 'photoBytes'),
        tags: captureAny(named: 'tags'),
        memo: any(named: 'memo'),
        linkedPhotoUrls: any(named: 'linkedPhotoUrls'),
      ),
    ).captured;

    // The photo stays with the toilet record, which is the one place it can
    // be viewed. Copying it would put the same image in Storage twice, with
    // two records able to delete only their own.
    expect(captured[0] as List<Uint8List>, isEmpty);
    expect(
      captured[1] as List<HealthRecordTag>,
      containsAll(<HealthRecordTag>[
        HealthRecordTag.diarrhea,
        HealthRecordTag.bloodyStool,
      ]),
    );
  });

  testWidgets('a failed copy does not make the saved record look lost', (
    tester,
  ) async {
    when(
      () => healthRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        recordedAt: any(named: 'recordedAt'),
        photoBytes: any(named: 'photoBytes'),
        tags: any(named: 'tags'),
        memo: any(named: 'memo'),
        linkedPhotoUrls: any(named: 'linkedPhotoUrls'),
      ),
    ).thenThrow(Exception('offline'));

    await pumpForm(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The record itself was written, which is the half that matters.
    verify(
      () => toiletRepository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        type: any(named: 'type'),
        stoolCondition: any(named: 'stoolCondition'),
        photoBytes: any(named: 'photoBytes'),
        recordedAt: any(named: 'recordedAt'),
        location: any(named: 'location'),
      ),
    ).called(1);
  });
}
