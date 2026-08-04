import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../models/weight_record.dart';

/// CRUD for spec section 3's weight records.
///
/// Spec 3.4 leaves same-day-entry behavior as a user setting ("同日に複数回
/// 記録された場合は上書きか併記かをユーザー設定で選べるようにする"). Rather
/// than baking a policy into this repository, we expose [findForDate] so the
/// UI layer can look up an existing same-day record and let the user choose
/// between calling [update] (overwrite) or [create] (append/併記) — both are
/// plain CRUD operations here, the decision is a presentation concern.
abstract class WeightRecordRepository {
  Stream<List<WeightRecord>> watchAll(String uid, String petId);

  /// Existing records already recorded on the same calendar day as [date],
  /// for the "overwrite or append?" prompt described above.
  Future<List<WeightRecord>> findForDate(
    String uid,
    String petId,
    DateTime date,
  );

  Future<WeightRecord> create({
    required String uid,
    required String petId,
    required DateTime measuredAt,
    required double weightKg,
  });

  Future<void> update(String uid, WeightRecord record);

  Future<void> delete(String uid, WeightRecord record);
}

class FirestoreWeightRecordRepository implements WeightRecordRepository {
  FirestoreWeightRecordRepository({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String petId,
  ) => _firestore.collection(FirestorePaths.weightRecords(uid, petId));

  @override
  Stream<List<WeightRecord>> watchAll(String uid, String petId) {
    return _collection(uid, petId)
        .orderBy('measured_at')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => WeightRecord.fromMap(d.data())).toList(),
        );
  }

  @override
  Future<List<WeightRecord>> findForDate(
    String uid,
    String petId,
    DateTime date,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final snap = await _collection(uid, petId)
        .where(
          'measured_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('measured_at', isLessThan: Timestamp.fromDate(dayEnd))
        .get();
    return snap.docs.map((d) => WeightRecord.fromMap(d.data())).toList();
  }

  @override
  Future<WeightRecord> create({
    required String uid,
    required String petId,
    required DateTime measuredAt,
    required double weightKg,
  }) async {
    final record = WeightRecord(
      weightId: _uuid.v4(),
      petId: petId,
      measuredAt: measuredAt,
      weightKg: weightKg,
    );
    await _collection(uid, petId).doc(record.weightId).set(record.toMap());
    return record;
  }

  @override
  Future<void> update(String uid, WeightRecord record) async {
    await _collection(
      uid,
      record.petId,
    ).doc(record.weightId).set(record.toMap());
  }

  @override
  Future<void> delete(String uid, WeightRecord record) async {
    await _collection(uid, record.petId).doc(record.weightId).delete();
  }
}
