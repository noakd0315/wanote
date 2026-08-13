import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wanote/features/billing/ads/ad_gate.dart';
import 'package:wanote/features/billing/ads/ad_manager.dart';
import 'package:wanote/features/billing/domain/billing_models.dart';
import 'package:wanote/features/daily_record/data/toilet_record_repository.dart';
import 'package:wanote/features/daily_record/presentation/toilet_record_form_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanote/features/daily_record/models/toilet_record.dart';

class MockToiletRecordRepository extends Mock
    implements ToiletRecordRepository {}

class MockAdManager extends Mock implements AdManager {}

class MockImagePicker extends Mock implements ImagePicker {}

class FakeStoolCondition extends Fake implements StoolCondition {}

/// The ordering rule that protects the owner's data.
///
/// An ad shown between the tap and the write landing can cost them the
/// record they just entered: the process can be killed behind a full-screen
/// ad, and the write never completes. Saving first means the only thing at
/// risk is the ad impression.
///
/// This is a one-line reordering to break, it looks harmless in a diff, and
/// nothing about the running app would reveal it -- the ad appears either
/// way. Hence a test that watches the order rather than the outcome.
void main() {
  setUpAll(() {
    registerFallbackValue(FakeStoolCondition());
    registerFallbackValue(ToiletType.stool);
    registerFallbackValue(ImageSource.camera);
  });

  late MockToiletRecordRepository repository;
  late MockAdManager adManager;
  late MockImagePicker imagePicker;
  late List<String> calls;

  setUp(() {
    repository = MockToiletRecordRepository();
    adManager = MockAdManager();
    imagePicker = MockImagePicker();
    calls = [];

    when(() => imagePicker.pickImage(source: any(named: 'source'))).thenAnswer(
      // A real 1x1 PNG, not arbitrary bytes: the form renders a preview of
      // whatever it is handed, and Image.memory throws on anything it
      // cannot decode.
      (_) async => XFile.fromData(
        _onePixelPng,
        name: 'stool.png',
        mimeType: 'image/png',
      ),
    );

    when(
      () => repository.create(
        uid: any(named: 'uid'),
        petId: any(named: 'petId'),
        type: any(named: 'type'),
        stoolCondition: any(named: 'stoolCondition'),
        photoBytes: any(named: 'photoBytes'),
        recordedAt: any(named: 'recordedAt'),
        location: any(named: 'location'),
      ),
    ).thenAnswer((_) async {
      calls.add('save');
      return _record();
    });
    when(adManager.maybeShowInterstitial).thenAnswer((_) async {
      calls.add('ad');
    });
    when(adManager.preloadInterstitial).thenAnswer((_) async {});
  });

  Future<void> pumpForm(WidgetTester tester) async {
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
          home: ToiletRecordFormScreen(
            uid: 'uid-1',
            petId: 'pet-1',
            repository: repository,
            imagePicker: imagePicker,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drives the real picker path so the photo arrives the way it does in
  /// the app, rather than being poked into state by the test.
  Future<void> attachPhoto(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    // The sheet offers camera or library; both go through the same picker.
    await tester.tap(find.text('カメラで撮影'));
    await tester.pumpAndSettle();
  }

  /// The photo preview pushes the save button out of the viewport, and the
  /// form is a ListView -- so the button is not merely off-screen, it has
  /// not been built at all and has to be scrolled to.
  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byType(FilledButton);
    await tester.scrollUntilVisible(
      save,
      200,
      // The form is not the only Scrollable in the tree, so name it.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('saves before it shows anything, when there is a photo', (
    tester,
  ) async {
    await pumpForm(tester);
    await attachPhoto(tester);
    await tapSave(tester);

    expect(calls, ['save', 'ad']);
  });

  testWidgets('a record with no photo shows no ad at all', (tester) async {
    // Recording a toilet visit is the everyday act this app exists for.
    // An ad in front of it every time would make the core feature
    // unpleasant (PLAN_ads decision 2).
    await pumpForm(tester);

    await tapSave(tester);

    expect(calls, ['save']);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

ToiletRecord _record() => ToiletRecord(
  toiletId: 'r1',
  petId: 'pet-1',
  type: ToiletType.stool,
  recordedAt: DateTime(2026, 8, 12),
);
