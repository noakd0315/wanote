import 'dart:typed_data';

import 'package:flutter/material.dart';

/// How a photo is framed: the alignment/zoom triple `PetProfile` already
/// persists, so nothing downstream (Firestore, `PetIconAvatar`,
/// `PetBackgroundPhoto`) has to change.
class PhotoCropResult {
  const PhotoCropResult({
    required this.alignmentX,
    required this.alignmentY,
    required this.zoom,
  });

  final double alignmentX;
  final double alignmentY;
  final double zoom;
}

/// Pinch-to-frame screen, used for both the pet's icon and its Home
/// background (PM request: adjust inside the image the way LINE and Facebook
/// do, rather than dragging bars underneath it).
///
/// The preview deliberately rebuilds the target widget's exact composition --
/// cover-fit with an alignment, then `Transform.scale` about that same
/// alignment -- instead of using an `InteractiveViewer`. Those two produce
/// different crops for photos that don't match the frame's aspect ratio, and
/// an InteractiveViewer would have meant converting its matrix back into
/// alignment/zoom, an approximation the user would notice as the photo
/// "jumping" on save. Driving the three stored values straight from the
/// gesture makes the preview literally the same widget tree the app will use,
/// so what is inside the frame is what gets saved.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({
    super.key,
    required this.imageBytes,
    required this.title,
    required this.confirmLabel,
    required this.hint,
    this.initial,
    this.frameAspectRatio = 1,
    this.circular = true,
  });

  final Uint8List imageBytes;

  /// Localized copy, passed in so this screen stays free of l10n lookups and
  /// can describe either target.
  final String title;
  final String confirmLabel;
  final String hint;

  /// Lets re-editing an existing photo start from how it currently looks
  /// rather than snapping back to centre.
  final PhotoCropResult? initial;

  /// Width / height of the frame the photo is being cropped to. 1 for the
  /// circular icon; the Home screen's own aspect ratio for the background,
  /// so the preview shows what will actually be visible there.
  final double frameAspectRatio;

  /// Whether to mask the frame to a circle. The icon is round; the
  /// background fills a rectangle.
  final bool circular;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  static const double _minZoom = 1;
  static const double _maxZoom = 5;

  double _alignmentX = 0;
  double _alignmentY = 0;
  double _zoom = 1;

  /// Intrinsic size of the photo. Needed because a photo whose shape differs
  /// from the frame's is already croppable at 1x -- cover-fit throws away
  /// part of the long edge, and alignment decides which part. Null until
  /// decoded; panning simply has a smaller range until then.
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

  /// Largest box with the frame's aspect ratio that fits in [constraints],
  /// leaving a margin so the photo's edges stay visible while dragging.
  Size _frameSize(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth * 0.9;
    final maxHeight = constraints.maxHeight * 0.9;
    final width = maxWidth / widget.frameAspectRatio <= maxHeight
        ? maxWidth
        : maxHeight * widget.frameAspectRatio;
    return Size(width, width / widget.frameAspectRatio);
  }

  /// How many viewport pixels the photo can travel along [axis] across the
  /// full -1..1 alignment range, at the current zoom.
  ///
  /// Two things contribute: the part of the photo that cover-fit pushes
  /// outside the frame (magnified by the zoom), and the extra that
  /// `Transform.scale` pushes out on top of it.
  double _panRange(Axis axis, Size frame) {
    final size = _imageSize;
    var coverOverflow = 0.0;
    if (size != null && size.width > 0 && size.height > 0) {
      final coverScale = frame.width / size.width > frame.height / size.height
          ? frame.width / size.width
          : frame.height / size.height;
      coverOverflow = axis == Axis.horizontal
          ? size.width * coverScale - frame.width
          : size.height * coverScale - frame.height;
    }
    final frameExtent = axis == Axis.horizontal ? frame.width : frame.height;
    return coverOverflow * _zoom + frameExtent * (_zoom - 1);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size frame) {
    final rangeX = _panRange(Axis.horizontal, frame);
    final rangeY = _panRange(Axis.vertical, frame);
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              PhotoCropResult(
                alignmentX: _alignmentX,
                alignmentY: _alignmentY,
                zoom: _zoom,
              ),
            ),
            child: Text(
              widget.confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final frame = _frameSize(constraints);
          final alignment = Alignment(_alignmentX, _alignmentY);
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: (details) => _onScaleUpdate(details, frame),
                    child: SizedBox(
                      width: frame.width,
                      height: frame.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRect(
                            // Same composition as PetIconAvatar /
                            // PetBackgroundPhoto -- keep these in step if
                            // either one changes.
                            child: Transform.scale(
                              scale: _zoom,
                              alignment: alignment,
                              child: Image.memory(
                                widget.imageBytes,
                                width: frame.width,
                                height: frame.height,
                                fit: BoxFit.cover,
                                alignment: alignment,
                              ),
                            ),
                          ),
                          // Non-interactive so pinch/drag reach the photo
                          // underneath.
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _FrameMaskPainter(
                                circular: widget.circular,
                              ),
                              size: frame,
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
                  widget.hint,
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

/// Outlines the frame, and dims outside it when the frame is a circle inside
/// a square box, so the saved area is unambiguous. A rectangular frame has no
/// outside to dim -- the box *is* the frame.
class _FrameMaskPainter extends CustomPainter {
  const _FrameMaskPainter({required this.circular});

  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white70;

    if (!circular) {
      canvas.drawRect(Offset.zero & size, border);
      return;
    }

    final radius = size.shortestSide / 2;
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addOval(
        Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      Paint()..color = Colors.black54,
    );
    canvas.drawCircle(size.center(Offset.zero), radius, border);
  }

  @override
  bool shouldRepaint(covariant _FrameMaskPainter oldDelegate) =>
      oldDelegate.circular != circular;
}
