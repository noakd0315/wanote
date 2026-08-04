import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../domain/models/prevention_program.dart';

/// CRUD + live list for `prevention_programs` (spec 5.3), scoped to one pet.
abstract class PreventionProgramRepository {
  Stream<List<PreventionProgram>> watchPrograms(String uid, String petId);

  /// [startDate] is optional and defaults to now -- PM request: "開始日は
  /// 不要" (the start date input isn't needed). The field itself is kept
  /// internally (still always populated) rather than removed outright,
  /// since [watchPrograms] orders by it and a Firestore `orderBy` silently
  /// excludes any doc missing the ordered field.
  Future<PreventionProgram> create({
    required String uid,
    required String petId,
    required PreventionType type,
    required String productName,
    required ScheduleType scheduleType,
    required bool active,
    DateTime? startDate,
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
    // Ascending (oldest-created first) so the seeded defaults display in
    // the PM-requested order -- 狂犬病>混合ワクチン>フィラリア予防>ノミ・
    // ダニ予防 -- which matches the order _seedDefaultsIfEmpty creates them
    // in, since start_date defaults to the creation instant (see `create`'s
    // doc comment).
    return _firestore
        .collection(FirestorePaths.preventionPrograms(uid, petId))
        .orderBy('start_date')
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
    required bool active,
    DateTime? startDate,
    int? intervalDays,
  }) async {
    final program = PreventionProgram(
      programId: _uuid.v4(),
      petId: petId,
      type: type,
      productName: productName,
      scheduleType: scheduleType,
      intervalDays: intervalDays,
      startDate: startDate ?? DateTime.now(),
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
