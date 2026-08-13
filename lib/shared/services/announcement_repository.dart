import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/announcement.dart';

/// Reads the app's notices. There is no write side by design -- notices are
/// authored in the Firebase console, and firestore.rules denies clients any
/// write at all.
abstract class AnnouncementRepository {
  /// Notices that should be showing right now, newest first.
  Stream<List<Announcement>> watchVisible();
}

class FirestoreAnnouncementRepository implements AnnouncementRepository {
  /// The Firestore handle is resolved lazily, not in the initializer.
  /// The sign-in screen builds one of these, and that screen is rendered in
  /// widget tests where no Firebase app exists -- constructing it must not
  /// be what throws.
  FirestoreAnnouncementRepository({FirebaseFirestore? firestore})
    : this._(firestore);

  const FirestoreAnnouncementRepository._(this._firestore);

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Notices are a handful at a time and old ones are deleted, so the whole
  /// collection is read and filtered on the device.
  ///
  /// Filtering server-side would mean range conditions on both `published_at`
  /// and `expires_at`, which Firestore cannot do in one query without a
  /// composite index -- and an index that has to be created before a notice
  /// can be published is exactly the operational cost this feature was meant
  /// to avoid.
  static const _limit = 50;

  @override
  Stream<List<Announcement>> watchVisible() {
    return _db
        .collection('announcements')
        .orderBy('published_at', descending: true)
        .limit(_limit)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => Announcement.fromMap(doc.id, doc.data()))
              .where((announcement) => announcement.isVisibleAt(now))
              .toList();
        });
  }
}

/// Which notices this device has already dismissed.
///
/// Deliberately local and not per-account. A dismissal is a fact about this
/// screen on this phone, not about the person: syncing it would mean letting
/// clients write somewhere, and the whole notice mechanism is valuable
/// precisely because it is read-only. Re-showing a notice after a reinstall
/// is a much smaller cost than opening a write path.
class AnnouncementReadState {
  AnnouncementReadState({Future<SharedPreferences>? sharedPreferences})
    : _prefsFuture = sharedPreferences ?? SharedPreferences.getInstance();

  static const prefsKey = 'announcements.dismissed_ids';

  final Future<SharedPreferences> _prefsFuture;

  Future<Set<String>> dismissedIds() async {
    final prefs = await _prefsFuture;
    return (prefs.getStringList(prefsKey) ?? const <String>[]).toSet();
  }

  Future<void> dismiss(String id) async {
    final prefs = await _prefsFuture;
    final ids = (prefs.getStringList(prefsKey) ?? const <String>[]).toSet()
      ..add(id);
    await prefs.setStringList(prefsKey, ids.toList());
  }
}
