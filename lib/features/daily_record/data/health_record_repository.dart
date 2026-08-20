import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../models/health_record.dart';
import 'photo_compressor.dart';

/// CRUD + timeline stream for spec section 2's photo-attached health
/// records. Photo compression is delegated to an injected [PhotoCompressor]
/// (see photo_compressor.dart) rather than called directly, so this
/// repository stays unit-testable (e.g. with `fake_cloud_firestore` + a fake
/// compressor) without touching platform channels or real network calls.
abstract class HealthRecordRepository {
  Stream<List<HealthRecord>> watchTimeline(String uid, String petId);

  /// Compresses and uploads [photoBytes] (raw, un-compressed image bytes;
  /// at most [HealthRecord.maxPhotos]), then creates the Firestore doc.
  Future<HealthRecord> create({
    required String uid,
    required String petId,
    required DateTime recordedAt,
    List<Uint8List> photoBytes,
    List<HealthRecordTag> tags,
    String? memo,
    List<String> linkedPhotoUrls,
  });

  /// Updates an existing record's tags/memo/recordedAt, optionally appending
  /// newly-compressed photos from [newPhotoBytes] on top of [retainedPhotoUrls]
  /// (the subset of the existing record's photo URLs the user kept after
  /// editing). Total photos after the update must not exceed
  /// [HealthRecord.maxPhotos].
  Future<HealthRecord> update({
    required String uid,
    required HealthRecord record,
    DateTime? recordedAt,
    List<HealthRecordTag>? tags,
    String? memo,
    List<String>? retainedPhotoUrls,
    List<Uint8List>? newPhotoBytes,
  });

  /// Deletes the Firestore doc and any uploaded photos under it in Storage.
  Future<void> delete({required String uid, required HealthRecord record});
}

class FirestoreHealthRecordRepository implements HealthRecordRepository {
  FirestoreHealthRecordRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    PhotoCompressor? photoCompressor,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _photoCompressor =
           photoCompressor ?? const FlutterImagePhotoCompressor(),
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final PhotoCompressor _photoCompressor;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String petId,
  ) => _firestore.collection(FirestorePaths.healthRecords(uid, petId));

  @override
  Stream<List<HealthRecord>> watchTimeline(String uid, String petId) {
    return _collection(uid, petId)
        .orderBy('recorded_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => HealthRecord.fromMap(d.data())).toList(),
        );
  }

  Future<List<String>> _uploadPhotos({
    required String uid,
    required String petId,
    required String recordId,
    required List<Uint8List> photoBytes,
    required int startIndex,
  }) async {
    // In parallel, not one after another. A record holds up to six photos,
    // and each one is a compress, an upload and a getDownloadURL round trip;
    // done in sequence the owner waits for the sum of all of them. Uploads
    // are the slow part and they are I/O, so overlapping them costs nothing
    // but shortens the wait to roughly the slowest single photo.
    //
    // This became visible only once ads stopped covering it: the interstitial
    // used to play over exactly this window (PM, 2026-08-21, testing with a
    // code applied -- premium accounts see no ad and so see the real wait).
    //
    // Future.wait keeps the results in the order they were requested, which
    // matters -- the index is part of the storage path and of the order the
    // photos are shown in.
    return Future.wait([
      for (var i = 0; i < photoBytes.length; i++)
        _compressAndUpload(
          bytes: photoBytes[i],
          path:
              'users/$uid/pets/$petId/health_records/$recordId/'
              '${startIndex + i}.jpg',
        ),
    ]);
  }

  Future<String> _compressAndUpload({
    required Uint8List bytes,
    required String path,
  }) async {
    final compressed = await _photoCompressor.compress(bytes);
    final ref = _storage.ref(path);
    await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  @override
  Future<HealthRecord> create({
    required String uid,
    required String petId,
    required DateTime recordedAt,
    List<Uint8List> photoBytes = const [],
    List<HealthRecordTag> tags = const [],
    String? memo,
    // Photos that already exist somewhere else, referenced rather than
    // uploaded again. A stool record copied into the daily log points at the
    // image the toilet record already holds: one file, one place, so the two
    // entries can never drift into showing different pictures.
    //
    // Deliberately not part of this record's own Storage folder, which is
    // what delete() clears -- deleting the copy must not reach into the
    // record it was copied from.
    List<String> linkedPhotoUrls = const [],
  }) async {
    assert(
      photoBytes.length <= HealthRecord.maxPhotos,
      'At most ${HealthRecord.maxPhotos} photos are allowed per health record.',
    );
    final recordId = _uuid.v4();
    final photoUrls = await _uploadPhotos(
      uid: uid,
      petId: petId,
      recordId: recordId,
      photoBytes: photoBytes,
      startIndex: 0,
    );
    final record = HealthRecord(
      recordId: recordId,
      petId: petId,
      recordedAt: recordedAt,
      photos: [...linkedPhotoUrls, ...photoUrls],
      tags: tags,
      memo: memo,
    );
    await _collection(uid, petId).doc(recordId).set(record.toMap());
    return record;
  }

  @override
  Future<HealthRecord> update({
    required String uid,
    required HealthRecord record,
    DateTime? recordedAt,
    List<HealthRecordTag>? tags,
    String? memo,
    List<String>? retainedPhotoUrls,
    List<Uint8List>? newPhotoBytes,
  }) async {
    final retained = retainedPhotoUrls ?? record.photos;
    final newBytes = newPhotoBytes ?? const <Uint8List>[];
    assert(
      retained.length + newBytes.length <= HealthRecord.maxPhotos,
      'At most ${HealthRecord.maxPhotos} photos are allowed per health record.',
    );
    final newUrls = await _uploadPhotos(
      uid: uid,
      petId: record.petId,
      recordId: record.recordId,
      photoBytes: newBytes,
      startIndex: retained.length,
    );
    final updated = record.copyWith(
      recordedAt: recordedAt,
      tags: tags,
      memo: memo,
      photos: [...retained, ...newUrls],
    );
    await _collection(
      uid,
      record.petId,
    ).doc(record.recordId).set(updated.toMap());
    // Photos dropped during the edit were only unlinked, never deleted, so
    // they stayed in Storage until the whole record was deleted. Someone who
    // removes a photo means it to be gone.
    //
    // After the write, not before: if the write fails the record still
    // points at those photos, and deleting first would leave it pointing at
    // nothing.
    await _deleteRemovedPhotos(
      uid: uid,
      record: record,
      previous: record.photos,
      retained: retained,
    );
    return updated;
  }

  /// Best-effort, and by URL rather than by path: the file names come from
  /// the upload index, and an edit renumbers nothing, so a name cannot be
  /// derived from position after photos have been removed.
  Future<void> _deleteRemovedPhotos({
    required String uid,
    required HealthRecord record,
    required List<String> previous,
    required List<String> retained,
  }) async {
    // Only files this record owns. A record copied from a stool entry points
    // at the toilet record's photo, and dropping that photo here must not
    // reach across and delete someone else's file -- the copy would take the
    // original's picture with it.
    final own =
        'users/$uid/pets/${record.petId}/health_records/${record.recordId}/';
    final removed = previous.where((url) => !retained.contains(url));
    for (final url in removed) {
      try {
        final ref = _storage.refFromURL(url);
        if (!ref.fullPath.startsWith(own)) continue;
        await ref.delete();
      } catch (_) {
        // A photo that will not delete is left for the record's own deletion
        // to sweep up. It must not make the edit look like it failed.
      }
    }
  }

  @override
  Future<void> delete({
    required String uid,
    required HealthRecord record,
  }) async {
    await _collection(uid, record.petId).doc(record.recordId).delete();
    // Best-effort cleanup: derive the folder ref from the known storage path
    // pattern rather than parsing download URLs (which are opaque/signed).
    final folderRef = _storage.ref(
      'users/$uid/pets/${record.petId}/health_records/${record.recordId}',
    );
    try {
      final listing = await folderRef.listAll();
      await Future.wait(listing.items.map((r) => r.delete()));
    } catch (_) {
      // Storage cleanup is best-effort; the Firestore doc deletion above is
      // the source of truth for whether the record is gone.
    }
  }
}
