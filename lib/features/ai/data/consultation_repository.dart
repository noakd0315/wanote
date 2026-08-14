import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../models/consultation.dart';

/// Firestore-backed consultation history (spec 6.2's "相談履歴一覧"),
/// scoped to one owner/pet pair via [FirestorePaths.consultations].
abstract class ConsultationRepository {
  Stream<List<Consultation>> watchHistory(String uid, String petId);

  /// Removes one stored consultation.
  ///
  /// A consultation holds what the owner asked about their dog and what came
  /// back. That is theirs to keep or not, and until now it could only
  /// accumulate.
  Future<void> delete({
    required String uid,
    required String petId,
    required String consultationId,
  });

  Future<Consultation> save({
    required String uid,
    required String petId,
    required String questionText,
    required String aiResponse,
    required List<String> referencedRecordIds,
  });
}

class FirestoreConsultationRepository implements ConsultationRepository {
  FirestoreConsultationRepository({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  @override
  Stream<List<Consultation>> watchHistory(String uid, String petId) {
    return _firestore
        .collection(FirestorePaths.consultations(uid, petId))
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Consultation.fromMap(d.data())).toList(),
        );
  }

  @override
  Future<Consultation> save({
    required String uid,
    required String petId,
    required String questionText,
    required String aiResponse,
    required List<String> referencedRecordIds,
  }) async {
    final consultation = Consultation(
      consultationId: _uuid.v4(),
      petId: petId,
      questionText: questionText,
      aiResponse: aiResponse,
      referencedRecordIds: referencedRecordIds,
      createdAt: DateTime.now(),
    );
    await _firestore
        .collection(FirestorePaths.consultations(uid, petId))
        .doc(consultation.consultationId)
        .set(consultation.toMap());
    return consultation;
  }

  @override
  Future<void> delete({
    required String uid,
    required String petId,
    required String consultationId,
  }) async {
    await _firestore
        .collection(FirestorePaths.consultations(uid, petId))
        .doc(consultationId)
        .delete();
  }
}
