import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Client-side photo resize/compression, per spec section 2.4 ("写真は端末
/// 側でリサイズ・圧縮してからアップロード") and 9's storage cost-reduction
/// note. Declared as an interface (rather than calling
/// `flutter_image_compress` directly from the repository) so repositories
/// stay unit-testable with a fake/mock implementation — `flutter_image_compress`
/// relies on platform channels that aren't available in plain `flutter test`.
abstract class PhotoCompressor {
  /// Returns re-encoded, resized image bytes suitable for upload. Should be
  /// a no-op-safe passthrough on failure rather than throwing, since a failed
  /// compression shouldn't block the user from saving a record — callers may
  /// choose to fall back to the original bytes.
  Future<Uint8List> compress(Uint8List original);
}

/// Default production implementation backed by `flutter_image_compress`.
class FlutterImagePhotoCompressor implements PhotoCompressor {
  const FlutterImagePhotoCompressor({
    this.quality = 80,
    this.minWidth = 1280,
    this.minHeight = 1280,
  });

  /// JPEG quality (0-100).
  final int quality;
  final int minWidth;
  final int minHeight;

  @override
  Future<Uint8List> compress(Uint8List original) async {
    final result = await FlutterImageCompress.compressWithList(
      original,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
    );
    return result;
  }
}
