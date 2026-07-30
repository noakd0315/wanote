import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../domain/models/medication.dart';

/// CRUD + live list for spec 5.2 (薬の記録), scoped to one pet.
abstract class MedicationRepository {
  Stream<List<Medication>> watchMedications(String uid, String petId);

  Future<Medication> create({
    required String uid,
    required String petId,
    required String name,
    required DateTime startDate,
    required bool reminderEnabled,
    String? dosage,
    DateTime? endDate,
    int? reminderHour,
    int? reminderMinute,
  });

  Future<void> update(String uid, Medication medication);

  Future<void> delete(String uid, String petId, String medicationId);
}

class FirestoreMedicationRepository implements MedicationRepository {
  FirestoreMedicationRepository({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  @override
  Stream<List<Medication>> watchMedications(String uid, String petId) {
    return _firestore
        .collection(FirestorePaths.medications(uid, petId))
        .orderBy('start_date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Medication.fromMap(d.data())).toList(),
        );
  }

  @override
  Future<Medication> create({
    required String uid,
    required String petId,
    required String name,
    required DateTime startDate,
    required bool reminderEnabled,
    String? dosage,
    DateTime? endDate,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final medication = Medication(
      medicationId: _uuid.v4(),
      petId: petId,
      name: name,
      dosage: dosage,
      startDate: startDate,
      endDate: endDate,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
    await _firestore
        .collection(FirestorePaths.medications(uid, petId))
        .doc(medication.medicationId)
        .set(medication.toMap());
    return medication;
  }

  @override
  Future<void> update(String uid, Medication medication) async {
    await _firestore
        .collection(FirestorePaths.medications(uid, medication.petId))
        .doc(medication.medicationId)
        .set(medication.toMap());
  }

  @override
  Future<void> delete(String uid, String petId, String medicationId) async {
    await _firestore
        .collection(FirestorePaths.medications(uid, petId))
        .doc(medicationId)
        .delete();
  }
}
