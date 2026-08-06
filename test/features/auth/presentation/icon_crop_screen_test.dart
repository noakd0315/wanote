import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/auth/presentation/screens/icon_crop_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

/// PM request: frame the pet icon by pinching inside the photo (LINE /
/// Facebook style) instead of dragging three sliders under it.
///
/// What is worth pinning here is the *direction and bounds* of the mapping
/// from gesture to the stored alignment/zoom triple, not exact pixel maths:
/// getting the sign wrong makes the photo run away from the finger, and a
/// missing clamp lets the user push the photo entirely out of the circle.
/// Both are invisible to the analyzer and to every other test.

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366AA),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Hosts the screen behind a button so the popped [IconCropResult] can be
/// captured the same way the pet profile form captures it.
Widget _host(
  Uint8List bytes, {
  IconCropResult? initial,
  required void Function(IconCropResult?) onResult,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<IconCropResult>(
                MaterialPageRoute(
                  builder: (_) =>
                      IconCropScreen(imageBytes: bytes, initial: initial),
                ),
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// Opens the crop screen and lets the photo finish decoding. The decode is a
/// real async round trip, so it needs runAsync -- without it _imageSize stays
/// null and panning has no range.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

Transform _preview(WidgetTester tester) => tester.widget<Transform>(
  find.ancestor(of: find.byType(Image), matching: find.byType(Transform)).first,
);

void main() {
  testWidgets('confirming without touching the photo keeps it centred at 1x', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _png(800, 400));
    IconCropResult? result;
    await tester.pumpWidget(_host(bytes!, onResult: (r) => result = r));
    await _open(tester);

    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.alignmentX, 0);
    expect(result!.alignmentY, 0);
    expect(result!.zoom, 1);
  });

  testWidgets('dragging the photo left reveals its right-hand side', (
    tester,
  ) async {
    // Deliberately wide: cover-fit already crops the long edge at 1x, so the
    // photo is pannable before any zoom -- exactly the case the sliders used
    // to handle and the one most likely to regress.
    final bytes = await tester.runAsync(() => _png(800, 400));
    IconCropResult? result;
    await tester.pumpWidget(_host(bytes!, onResult: (r) => result = r));
    await _open(tester);

    await tester.dragFrom(
      tester.getCenter(find.byType(Image)),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(
      result!.alignmentX,
      greaterThan(0),
      reason:
          'Pushing the photo left should bring its right side into view; '
          'a flipped sign makes the photo run away from the finger.',
    );
    expect(result!.zoom, 1, reason: 'A one-finger drag must not change zoom.');
  });

  testWidgets('panning past the edge clamps instead of losing the photo', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _png(800, 400));
    IconCropResult? result;
    await tester.pumpWidget(_host(bytes!, onResult: (r) => result = r));
    await _open(tester);

    await tester.dragFrom(
      tester.getCenter(find.byType(Image)),
      const Offset(-5000, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(result!.alignmentX, 1.0);
  });

  testWidgets('a square photo cannot be panned until it is zoomed in', (
    tester,
  ) async {
    // Nothing is cropped away at 1x, so there is nothing to pan to; letting
    // it move would drag the photo off the circle and leave a blank wedge.
    final bytes = await tester.runAsync(() => _png(400, 400));
    IconCropResult? result;
    await tester.pumpWidget(_host(bytes!, onResult: (r) => result = r));
    await _open(tester);

    await tester.dragFrom(
      tester.getCenter(find.byType(Image)),
      const Offset(-120, -120),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(result!.alignmentX, 0);
    expect(result!.alignmentY, 0);
  });

  testWidgets('re-editing starts from the framing already saved', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _png(800, 400));
    await tester.pumpWidget(
      _host(
        bytes!,
        initial: const IconCropResult(
          alignmentX: -0.5,
          alignmentY: 0.25,
          zoom: 2.5,
        ),
        onResult: (_) {},
      ),
    );
    await _open(tester);

    // The preview must open showing the current crop -- snapping back to
    // centre would silently discard framing the user already approved.
    final transform = _preview(tester);
    expect(transform.alignment, const Alignment(-0.5, 0.25));
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(2.5, 0.001));
  });
}
