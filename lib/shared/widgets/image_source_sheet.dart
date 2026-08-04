import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shows a "カメラで撮影" / "フォトライブラリから選択" bottom sheet. [onCamera]/
/// [onGallery] are invoked directly inside each option's own `onTap` --
/// *not* after `await`-ing the sheet's own result in the caller -- because
/// iOS Safari only treats a file-picker invocation (what `ImagePicker.
/// pickImage`/`pickMultiImage` triggers under the hood on web) as a
/// trusted user gesture when it happens synchronously within a real tap
/// handler. Awaiting `showModalBottomSheet`'s returned Future first (the
/// original shape of this code) crosses an event-loop boundary between the
/// tap and the picker call, which silently no-ops the picker on iPhone
/// while working fine on Android/desktop, which don't enforce this as
/// strictly (PM report: "アルバムから写真を設定できません").
///
/// Callers should pass a plain synchronous closure that kicks off their
/// own (unawaited) async pick-and-handle flow, e.g.:
/// ```dart
/// showImageSourceSheet(
///   context: context,
///   onCamera: () => _pickAndAdd(ImageSource.camera),
///   onGallery: () => _pickAndAdd(ImageSource.gallery),
/// );
/// ```
void showImageSourceSheet({
  required BuildContext context,
  required VoidCallback onCamera,
  required VoidCallback onGallery,
}) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.imageSourceCameraOption),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onCamera();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.imageSourceGalleryOption),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onGallery();
            },
          ),
        ],
      ),
    ),
  );
}
