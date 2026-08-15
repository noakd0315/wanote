import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../domain/models/prevention_record.dart';
import 'certificate_storage_service.dart';
import '../domain/models/medication.dart' show ReminderTime;

/// CRUD + live list for `prevention_records` (spec 5.3), scoped to one pet.
/// Records live in a pet-level subcollection (not nested under the program)
/// because the pet-level `next_due_date`/certificate list view (spec's
/// certificate list requirement) needs to query across all of a pet's
/// programs at once; `program_id` is kept on each record for filtering down
/// to one program's history when needed.
abstract class PreventionRecordRepository {
  Stream<List<PreventionRecord>> watchRecords(String uid, String petId);

  Stream<List<PreventionRecord>> watchRecordsForProgram(
    String uid,
    String petId,
    String programId,
  );

  Future<PreventionRecord> create({
    required String uid,
    required String petId,
    required String programId,
    required DateTime administeredAt,
    String? dosage,
    String? visitId,
    String? hospitalName,
    DateTime? nextDueDate,
    bool reminderEnabled = true,
    ReminderTime? reminderTime,
    String? certificateFile,
    Map<String, dynamic>? ocrExtractedData,
    double? ocrConfidence,
  });

  Future<void> update(String uid, PreventionRecord record);

  Future<void> delete(String uid, String petId, String recordId);
}

class FirestorePreventionRecordRepository
    implements PreventionRecordRepository {
  FirestorePreventionRecordRepository({
    FirebaseFirestore? firestore,
    CertificateStorageService? certificateStorage,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _certificateStorage =
           certificateStorage ?? FirebaseCertificateStorageService(),
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final CertificateStorageService _certificateStorage;
  final Uuid _uuid;

  @override
  Stream<List<PreventionRecord>> watchRecords(String uid, String petId) {
    return _firestore
        .collection(FirestorePaths.preventionRecords(uid, petId))
        .orderBy('administered_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => PreventionRecord.fromMap(d.data())).toList(),
        );
  }

  @override
  Stream<List<PreventionRecord>> watchRecordsForProgram(
    String uid,
    String petId,
    String programId,
  ) {
    return _firestore
        .collection(FirestorePaths.preventionRecords(uid, petId))
        .where('program_id', isEqualTo: programId)
        .orderBy('administered_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => PreventionRecord.fromMap(d.data())).toList(),
        );
  }

  @override
  Future<PreventionRecord> create({
    required String uid,
    required String petId,
    required String programId,
    required DateTime administeredAt,
    String? dosage,
    String? visitId,
    String? hospitalName,
    DateTime? nextDueDate,
    bool reminderEnabled = true,
    ReminderTime? reminderTime,
    String? certificateFile,
    Map<String, dynamic>? ocrExtractedData,
    double? ocrConfidence,
  }) async {
    final record = PreventionRecord(
      recordId: _uuid.v4(),
      programId: programId,
      petId: petId,
      administeredAt: administeredAt,
      dosage: dosage,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
      visitId: visitId,
      hospitalName: hospitalName,
      nextDueDate: nextDueDate,
      certificateFile: certificateFile,
      ocrExtractedData: ocrExtractedData,
      ocrConfidence: ocrConfidence,
    );
    await _firestore
        .collection(FirestorePaths.preventionRecords(uid, petId))
        .doc(record.recordId)
        .set(record.toMap());
    return record;
  }

  @override
  Future<void> update(String uid, PreventionRecord record) async {
    await _firestore
        .collection(FirestorePaths.preventionRecords(uid, record.petId))
        .doc(record.recordId)
        .set(record.toMap());
  }

  @override
  Future<void> delete(String uid, String petId, String recordId) async {
    await _firestore
        .collection(FirestorePaths.preventionRecords(uid, petId))
        .doc(recordId)
        .delete();
    // The document first, then the image. Reversed, a failure here would
    // leave a record pointing at a picture that no longer exists; this way
    // the worst case is a file nobody can reach, which account deletion
    // sweeps up.
    //
    // Best-effort, like the other record types: the owner asked for this to
    // be gone, and the document being gone is what they see. An error here
    // must not make the deletion look as though it failed.
    try {
      await _certificateStorage.delete(
        uid: uid,
        petId: petId,
        recordId: recordId,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not delete the certificate image',
        name: 'PreventionRecordRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
