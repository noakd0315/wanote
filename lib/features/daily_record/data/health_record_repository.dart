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
    final urls = <String>[];
    for (var i = 0; i < photoBytes.length; i++) {
      final compressed = await _photoCompressor.compress(photoBytes[i]);
      final ref = _storage.ref(
        'users/$uid/pets/$petId/health_records/$recordId/${startIndex + i}.jpg',
      );
      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  @override
  Future<HealthRecord> create({
    required String uid,
    required String petId,
    required DateTime recordedAt,
    List<Uint8List> photoBytes = const [],
    List<HealthRecordTag> tags = const [],
    String? memo,
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
      photos: photoUrls,
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
    return updated;
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
