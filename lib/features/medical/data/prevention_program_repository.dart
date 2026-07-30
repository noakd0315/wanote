import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../domain/models/prevention_program.dart';

/// CRUD + live list for `prevention_programs` (spec 5.3), scoped to one pet.
abstract class PreventionProgramRepository {
  Stream<List<PreventionProgram>> watchPrograms(String uid, String petId);

  Future<PreventionProgram> create({
    required String uid,
    required String petId,
    required PreventionType type,
    required String productName,
    required ScheduleType scheduleType,
    required DateTime startDate,
    required bool active,
    int? intervalDays,
  });

  Future<void> update(String uid, PreventionProgram program);

  Future<void> delete(String uid, String petId, String programId);
}

class FirestorePreventionProgramRepository
    implements PreventionProgramRepository {
  FirestorePreventionProgramRepository({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  @override
  Stream<List<PreventionProgram>> watchPrograms(String uid, String petId) {
    return _firestore
        .collection(FirestorePaths.preventionPrograms(uid, petId))
        .orderBy('start_date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PreventionProgram.fromMap(d.data()))
              .toList(),
        );
  }

  @override
  Future<PreventionProgram> create({
    required String uid,
    required String petId,
    required PreventionType type,
    required String productName,
    required ScheduleType scheduleType,
    required DateTime startDate,
    required bool active,
    int? intervalDays,
  }) async {
    final program = PreventionProgram(
      programId: _uuid.v4(),
      petId: petId,
      type: type,
      productName: productName,
      scheduleType: scheduleType,
      intervalDays: intervalDays,
      startDate: startDate,
      active: active,
    );
    await _firestore
        .collection(FirestorePaths.preventionPrograms(uid, petId))
        .doc(program.programId)
        .set(program.toMap());
    return program;
  }

  @override
  Future<void> update(String uid, PreventionProgram program) async {
    await _firestore
        .collection(FirestorePaths.preventionPrograms(uid, program.petId))
        .doc(program.programId)
        .set(program.toMap());
  }

  @override
  Future<void> delete(String uid, String petId, String programId) async {
    await _firestore
        .collection(FirestorePaths.preventionPrograms(uid, petId))
        .doc(programId)
        .delete();
  }
}
