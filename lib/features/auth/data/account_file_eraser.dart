import 'package:firebase_storage/firebase_storage.dart';

/// Deletes every Cloud Storage object belonging to one account.
abstract class AccountFileEraser {
  /// Removes everything under `users/{uid}/` -- pet photos, health- and
  /// toilet-record photos, and vaccination certificate scans.
  ///
  /// Idempotent, like [AccountDocumentEraser.erase].
  Future<void> erase(String uid);
}

class StorageAccountFileEraser implements AccountFileEraser {
  StorageAccountFileEraser({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Storage has no recursive delete either, and `list` is paginated.
  static const _pageSize = 100;

  @override
  Future<void> erase(String uid) {
    // Every upload path in the app starts here (pet_profile_repository,
    // health_record_repository, toilet_record_repository,
    // certificate_storage_service), so the whole account is one prefix --
    // no need to know which pets or records ever existed.
    return _eraseUnder(_storage.ref('users/$uid'));
  }

  Future<void> _eraseUnder(Reference folder) async {
    String? pageToken;
    do {
      final page = await folder.list(
        ListOptions(maxResults: _pageSize, pageToken: pageToken),
      );
      await Future.wait(page.items.map((item) => item.delete()));
      for (final subfolder in page.prefixes) {
        await _eraseUnder(subfolder);
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null);
  }
}
