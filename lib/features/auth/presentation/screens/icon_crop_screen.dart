import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Result of framing an icon: the same alignment/zoom triple the pet profile
/// already persists, so nothing downstream (Firestore, `PetIconAvatar`) has to
/// change.
class IconCropResult {
  const IconCropResult({
    required this.alignmentX,
    required this.alignmentY,
    required this.zoom,
  });

  final double alignmentX;
  final double alignmentY;
  final double zoom;
}

/// Pinch-to-frame screen for the pet's icon, replacing the three
/// offset/zoom sliders (PM request: adjust inside the image the way LINE and
/// Facebook do, rather than dragging bars underneath it).
///
/// The preview deliberately rebuilds `PetIconAvatar`'s exact composition
/// (cover-fit with an alignment, then `Transform.scale` about that same
/// alignment) instead of using an `InteractiveViewer`. Those two produce
/// different crops for non-square photos, and an InteractiveViewer would have
/// meant converting its matrix back into alignment/zoom — an approximation the
/// user would notice as the icon "jumping" on save. Driving the three stored
/// values straight from the gesture makes the preview literally the same
/// widget tree the avatar will use, so what is inside the circle is what gets
/// saved.
class IconCropScreen extends StatefulWidget {
  const IconCropScreen({super.key, required this.imageBytes, this.initial});

  final Uint8List imageBytes;

  /// Lets re-editing an existing icon start from how it currently looks
  /// rather than snapping back to centre.
  final IconCropResult? initial;

  @override
  State<IconCropScreen> createState() => _IconCropScreenState();
}

class _IconCropScreenState extends State<IconCropScreen> {
  static const double _minZoom = 1;
  static const double _maxZoom = 5;

  double _alignmentX = 0;
  double _alignmentY = 0;
  double _zoom = 1;

  /// Intrinsic size of the photo. Needed because a non-square photo is
  /// already croppable at 1x -- cover-fit throws away part of the long edge,
  /// and alignment decides which part. Null until decoded; panning simply has
  /// a smaller range until then.
  Size? _imageSize;

  // Gesture start state: onScaleUpdate reports scale relative to the start of
  // the gesture, so the zoom it multiplies has to be the zoom we started at.
  double _zoomAtGestureStart = 1;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _alignmentX = initial.alignmentX;
      _alignmentY = initial.alignmentY;
      _zoom = initial.zoom.clamp(_minZoom, _maxZoom);
    }
    _decodeImageSize();
  }

  Future<void> _decodeImageSize() async {
    final image = await decodeImageFromList(widget.imageBytes);
    if (!mounted) return;
    setState(
      () => _imageSize = Size(image.width.toDouble(), image.height.toDouble()),
    );
  }

  /// Side of the square crop window, and of the box the photo is laid out in.
  double _cropSize(BoxConstraints constraints) =>
      (constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight) *
      0.8;

  /// How many viewport pixels the photo can travel along [axis] across the
  /// full -1..1 alignment range, at the current zoom.
  ///
  /// Two things contribute: the part of the photo that cover-fit pushes
  /// outside the square (magnified by the zoom), and the extra that
  /// `Transform.scale` pushes out on top of it.
  double _panRange(Axis axis, double cropSize) {
    final size = _imageSize;
    var coverOverflow = 0.0;
    if (size != null && size.width > 0 && size.height > 0) {
      final coverScale = cropSize / size.width > cropSize / size.height
          ? cropSize / size.width
          : cropSize / size.height;
      coverOverflow = axis == Axis.horizontal
          ? size.width * coverScale - cropSize
          : size.height * coverScale - cropSize;
    }
    return coverOverflow * _zoom + cropSize * (_zoom - 1);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double cropSize) {
    final rangeX = _panRange(Axis.horizontal, cropSize);
    final rangeY = _panRange(Axis.vertical, cropSize);
    setState(() {
      _zoom = (_zoomAtGestureStart * details.scale).clamp(_minZoom, _maxZoom);
      // Dragging right should pull the photo right, revealing what is off to
      // its left -- which is a *smaller* alignment, hence the negation.
      if (rangeX > 0) {
        _alignmentX = (_alignmentX - 2 * details.focalPointDelta.dx / rangeX)
            .clamp(-1.0, 1.0);
      }
      if (rangeY > 0) {
        _alignmentY = (_alignmentY - 2 * details.focalPointDelta.dy / rangeY)
            .clamp(-1.0, 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.iconCropTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              IconCropResult(
                alignmentX: _alignmentX,
                alignmentY: _alignmentY,
                zoom: _zoom,
              ),
            ),
            child: Text(
              l10n.iconCropConfirmButton,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cropSize = _cropSize(constraints);
          final alignment = Alignment(_alignmentX, _alignmentY);
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: (details) =>
                        _onScaleUpdate(details, cropSize),
                    child: SizedBox(
                      width: cropSize,
                      height: cropSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRect(
                            // Same composition as PetIconAvatar -- keep these
                            // two in step if either one changes.
                            child: Transform.scale(
                              scale: _zoom,
                              alignment: alignment,
                              child: Image.memory(
                                widget.imageBytes,
                                width: cropSize,
                                height: cropSize,
                                fit: BoxFit.cover,
                                alignment: alignment,
                              ),
                            ),
                          ),
                          // Non-interactive so pinch/drag reach the photo
                          // underneath.
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CircleMaskPainter(),
                              size: Size.square(cropSize),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Text(
                  l10n.iconCropHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dims everything outside the circle so the saved area is unambiguous.
class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addOval(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.width / 2,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      Paint()..color = Colors.black54,
    );
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white70,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => false;
}
