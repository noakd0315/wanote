import 'package:image_picker/image_picker.dart';

/// Picking limits, applied by the platform before any bytes reach Dart.
///
/// Without them `image_picker` hands over the camera's full-resolution
/// image. A recent phone shoots twelve megapixels or more, and a health
/// record holds up to six photos -- enough to run the process out of memory
/// and have Android kill the app, which is the crash the PM reported while
/// attaching photos.
///
/// Passing the limits is what fixes it, not compressing afterwards: by the
/// time the app can compress, it is already holding the thing that was too
/// big. This is also why the limits belong in one place rather than at each
/// call site -- five of them existed and not one passed anything.
///
/// 1600px still exceeds what the app stores (photos are compressed to 1280
/// on save) so nothing visible is lost, and it cuts a twelve-megapixel
/// capture to roughly a fifth of the pixels.
const int kPickedImageMaxDimension = 1600;

/// Certificates are photographs of printed documents read by OCR, so they
/// keep more detail: small print survives at 2000px where it would not at
/// 1600. Still a large reduction from an unbounded capture.
const int kPickedCertificateMaxDimension = 2000;

const int kPickedImageQuality = 88;

extension DownscaledPicking on ImagePicker {
  /// [pickImage] with the limits above already applied.
  Future<XFile?> pickImageDownscaled({
    required ImageSource source,
    int maxDimension = kPickedImageMaxDimension,
  }) => pickImage(
    source: source,
    maxWidth: maxDimension.toDouble(),
    maxHeight: maxDimension.toDouble(),
    imageQuality: kPickedImageQuality,
  );

  /// [pickMultiImage] with the same limits. The multi-picker is the one that
  /// matters most: it is the only path that can deliver six images at once.
  Future<List<XFile>> pickMultiImageDownscaled({
    int? limit,
    int maxDimension = kPickedImageMaxDimension,
  }) => pickMultiImage(
    limit: limit,
    maxWidth: maxDimension.toDouble(),
    maxHeight: maxDimension.toDouble(),
    imageQuality: kPickedImageQuality,
  );
}
