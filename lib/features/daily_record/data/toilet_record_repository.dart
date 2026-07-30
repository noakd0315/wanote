import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../models/toilet_record.dart';
import 'photo_compressor.dart';

/// CRUD + timeline stream for spec section 4's one-tap toilet records.
/// Photo attachment (spec 4.2: "写真添付（血便など異常時の記録用、任意）")
/// reuses the same injectable [PhotoCompressor] as health records.
abstract class ToiletRecordRepository {
  Stream<List<ToiletRecord>> watchTimeline(String uid, String petId);

  /// Creates a one-tap record. [recordedAt] defaults to `DateTime.now()` to
  /// match spec 4.2's "記録時刻は自動入力". [stoolCondition] is required when
  /// [type] is [ToiletType.stool] (asserted here) and ignored for
  /// [ToiletType.urine].
  Future<ToiletRecord> create({
    required String uid,
    required String petId,
    required ToiletType type,
    StoolCondition? stoolCondition,
    Uint8List? photoBytes,
    DateTime? recordedAt,
  });

  Future<ToiletRecord> update({
    required String uid,
    required ToiletRecord record,
    StoolCondition? stoolCondition,
    Uint8List? newPhotoBytes,
    bool clearPhoto = false,
  });

  Future<void> delete({required String uid, required ToiletRecord record});
}

class FirestoreToiletRecordRepository implements ToiletRecordRepository {
  FirestoreToiletRecordRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    PhotoCompressor? photoCompressor,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _photoCompressor = photoCompressor ?? const FlutterImagePhotoCompressor(),
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final PhotoCompressor _photoCompressor;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _collection(String uid, String petId) =>
      _firestore.collection(FirestorePaths.toiletRecords(uid, petId));

  @override
  Stream<List<ToiletRecord>> watchTimeline(String uid, String petId) {
    return _collection(uid, petId)
        .orderBy('recorded_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ToiletRecord.fromMap(d.data())).toList());
  }

  Future<String> _uploadPhoto(String uid, String petId, String toiletId, Uint8List bytes) async {
    final compressed = await _photoCompressor.compress(bytes);
    final ref = _storage.ref('users/$uid/pets/$petId/toilet_records/$toiletId.jpg');
    await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  @override
  Future<ToiletRecord> create({
    required String uid,
    required String petId,
    required ToiletType type,
    StoolCondition? stoolCondition,
    Uint8List? photoBytes,
    DateTime? recordedAt,
  }) async {
    assert(
      type != ToiletType.stool || stoolCondition != null,
      'stoolCondition is required when type is ToiletType.stool (spec 4.3).',
    );
    final toiletId = _uuid.v4();
    final photoUrl = photoBytes != null
        ? await _uploadPhoto(uid, petId, toiletId, photoBytes)
        : null;
    final record = ToiletRecord(
      toiletId: toiletId,
      petId: petId,
      recordedAt: recordedAt ?? DateTime.now(),
      type: type,
      stoolCondition: type == ToiletType.stool ? stoolCondition : null,
      photo: photoUrl,
    );
    await _collection(uid, petId).doc(toiletId).set(record.toMap());
    return record;
  }

  @override
  Future<ToiletRecord> update({
    required String uid,
    required ToiletRecord record,
    StoolCondition? stoolCondition,
    Uint8List? newPhotoBytes,
    bool clearPhoto = false,
  }) async {
    final photoUrl = newPhotoBytes != null
        ? await _uploadPhoto(uid, record.petId, record.toiletId, newPhotoBytes)
        : (clearPhoto ? null : record.photo);
    final updated = record.copyWith(
      stoolCondition: stoolCondition,
      photo: photoUrl,
      clearPhoto: photoUrl == null,
    );
    await _collection(uid, record.petId).doc(record.toiletId).set(updated.toMap());
    return updated;
  }

  @override
  Future<void> delete({required String uid, required ToiletRecord record}) async {
    await _collection(uid, record.petId).doc(record.toiletId).delete();
    if (record.photo != null) {
      try {
        await _storage.ref('users/$uid/pets/${record.petId}/toilet_records/${record.toiletId}.jpg').delete();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }
}
