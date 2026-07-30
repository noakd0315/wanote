import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../domain/models/visit.dart';

/// CRUD + live list for spec 5.1 (通院履歴), scoped to one pet.
abstract class VisitRepository {
  Stream<List<Visit>> watchVisits(String uid, String petId);

  Future<Visit> create({
    required String uid,
    required String petId,
    required DateTime visitedAt,
    String? hospitalName,
    String? diagnosis,
    int? cost,
    DateTime? nextVisitDate,
  });

  Future<void> update(String uid, Visit visit);

  Future<void> delete(String uid, String petId, String visitId);
}

class FirestoreVisitRepository implements VisitRepository {
  FirestoreVisitRepository({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  @override
  Stream<List<Visit>> watchVisits(String uid, String petId) {
    return _firestore
        .collection(FirestorePaths.visits(uid, petId))
        .orderBy('visited_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Visit.fromMap(d.data())).toList());
  }

  @override
  Future<Visit> create({
    required String uid,
    required String petId,
    required DateTime visitedAt,
    String? hospitalName,
    String? diagnosis,
    int? cost,
    DateTime? nextVisitDate,
  }) async {
    final visit = Visit(
      visitId: _uuid.v4(),
      petId: petId,
      visitedAt: visitedAt,
      hospitalName: hospitalName,
      diagnosis: diagnosis,
      cost: cost,
      nextVisitDate: nextVisitDate,
    );
    await _firestore
        .collection(FirestorePaths.visits(uid, petId))
        .doc(visit.visitId)
        .set(visit.toMap());
    return visit;
  }

  @override
  Future<void> update(String uid, Visit visit) async {
    await _firestore
        .collection(FirestorePaths.visits(uid, visit.petId))
        .doc(visit.visitId)
        .set(visit.toMap());
  }

  @override
  Future<void> delete(String uid, String petId, String visitId) async {
    await _firestore
        .collection(FirestorePaths.visits(uid, petId))
        .doc(visitId)
        .delete();
  }
}
