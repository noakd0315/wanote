import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/data/certificate_cache_service.dart';
import 'package:wanote/features/medical/data/prevention_program_repository.dart';
import 'package:wanote/features/medical/data/prevention_record_repository.dart';
import 'package:wanote/features/medical/domain/models/prevention_program.dart';
import 'package:wanote/features/medical/domain/models/prevention_record.dart';
import 'package:wanote/features/medical/presentation/prevention/certificate_list_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

/// Covers the two PM requests for the certificate list:
///   1. the tile names the program between the photo and the date, so a
///      thumbnail + date alone no longer leaves you guessing which
///      vaccination it is;
///   2. the detail view can be pinch-zoomed, since certificates are dense
///      small print.
///
/// Driven through real gestures rather than the browser: synthetic pointer
/// events don't reach Flutter's gesture arena from JS, so a pinch can only
/// be exercised faithfully from a widget test.

const _uid = 'uid-1';
const _petId = 'pet-1';

final _record = PreventionRecord(
  recordId: 'rec-1',
  programId: 'prog-1',
  petId: _petId,
  administeredAt: DateTime(2026, 4, 8),
  certificateFile: 'https://example.test/cert.png',
);

final _program = PreventionProgram(
  programId: 'prog-1',
  petId: _petId,
  type: PreventionType.vaccine,
  productName: '狂犬病ワクチン',
  scheduleType: ScheduleType.annual,
  startDate: DateTime(2026, 1, 1),
  active: true,
);

class _FakeRecordRepository implements PreventionRecordRepository {
  @override
  Stream<List<PreventionRecord>> watchRecords(String uid, String petId) =>
      Stream.value([_record]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProgramRepository implements PreventionProgramRepository {
  @override
  Stream<List<PreventionProgram>> watchPrograms(String uid, String petId) =>
      Stream.value([_program]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Returns no cached file, which is the web/first-view path: the widget then
/// falls back to the remote URL.
class _NoCacheService implements CertificateCacheService {
  @override
  Future<File?> getOrDownload({
    required String recordId,
    required String? remoteUrl,
  }) async => null;

  @override
  Future<bool> isCached(String recordId) async => false;

  @override
  Future<void> evict(String recordId) async {}
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: CertificateListScreen(
        uid: _uid,
        petId: _petId,
        repository: _FakeRecordRepository(),
        programRepository: _FakeProgramRepository(),
        cacheService: _NoCacheService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tile shows the program name above the administered date', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('狂犬病ワクチン'), findsOneWidget);
    expect(find.text('2026-04-08'), findsOneWidget);

    // The name must sit between the photo and the date, not after it.
    final nameY = tester.getCenter(find.text('狂犬病ワクチン')).dy;
    final dateY = tester.getCenter(find.text('2026-04-08')).dy;
    expect(nameY, lessThan(dateY));
  });

  testWidgets('tapping a tile opens a zoomable viewer', (tester) async {
    await _pumpScreen(tester);

    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.text('狂犬病ワクチン'));
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.scaleEnabled, isTrue);
    expect(viewer.maxScale, greaterThan(1));
  });

  testWidgets('a pinch gesture actually scales the certificate', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('狂犬病ワクチン'));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 1.0);

    // Two fingers moving apart == pinch out.
    final centre = tester.getCenter(find.byType(InteractiveViewer));
    final finger1 = await tester.startGesture(centre - const Offset(20, 0));
    final finger2 = await tester.startGesture(centre + const Offset(20, 0));
    await finger1.moveBy(const Offset(-80, 0));
    await finger2.moveBy(const Offset(80, 0));
    await tester.pump();
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();

    expect(
      controller.value.getMaxScaleOnAxis(),
      greaterThan(1.0),
      reason: 'Pinching out must magnify the certificate.',
    );
  });

  testWidgets('double-tap zooms in, and a second double-tap resets', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('狂犬病ワクチン'));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    final centre = tester.getCenter(find.byType(InteractiveViewer));

    // kDoubleTapMinTime must elapse between the taps, otherwise Flutter
    // treats them as one tap and the gesture never fires.
    Future<void> doubleTap() async {
      await tester.tapAt(centre);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(centre);
      await tester.pumpAndSettle();
    }

    await doubleTap();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));

    await doubleTap();
    expect(controller.value.getMaxScaleOnAxis(), 1.0);
  });
}
