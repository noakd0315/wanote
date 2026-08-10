import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:wanote/features/daily_record/data/weight_record_repository.dart';

/// Not one of the required pure-class test suites (those are under
/// test/features/daily_record/domain/), but a lightweight extra check that
/// the Firestore wire format really uses the spec's exact field names
/// (weight_id, pet_id, measured_at, weight_kg) via fake_cloud_firestore,
/// since Agent C/D compatibility depends on that.
void main() {
  late FakeFirebaseFirestore firestore;
  late WeightRecordRepository repository;
  const uid = 'user-1';
  const petId = 'pet-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreWeightRecordRepository(
      firestore: firestore,
      uuid: const Uuid(),
    );
  });

  test('create() writes a doc with the spec field names', () async {
    final record = await repository.create(
      uid: uid,
      petId: petId,
      measuredAt: DateTime(2026, 7, 15),
      weightKg: 12.4,
    );

    final snap = await firestore
        .collection('users/$uid/pets/$petId/weight_records')
        .doc(record.weightId)
        .get();
    final data = snap.data()!;
    expect(data['weight_id'], record.weightId);
    expect(data['pet_id'], petId);
    expect(data['measured_at'], isA<Timestamp>());
    expect(data['weight_kg'], 12.4);
  });

  test('watchAll streams records ordered by measured_at', () async {
    await repository.create(
      uid: uid,
      petId: petId,
      measuredAt: DateTime(2026, 7, 10),
      weightKg: 12.0,
    );
    await repository.create(
      uid: uid,
      petId: petId,
      measuredAt: DateTime(2026, 7, 1),
      weightKg: 11.5,
    );

    final records = await repository.watchAll(uid, petId).first;
    expect(records.map((r) => r.weightKg), [11.5, 12.0]);
  });

  test('findForDate only returns records on that exact calendar day', () async {
    await repository.create(
      uid: uid,
      petId: petId,
      measuredAt: DateTime(2026, 7, 10, 8, 0),
      weightKg: 12.0,
    );
    await repository.create(
      uid: uid,
      petId: petId,
      measuredAt: DateTime(2026, 7, 11),
      weightKg: 12.1,
    );

    final found = await repository.findForDate(
      uid,
      petId,
      DateTime(2026, 7, 10, 20, 0),
    );
    expect(found, hasLength(1));
    expect(found.first.weightKg, 12.0);
  });

  test('delete removes the doc', () async {
    final record = await repository.create(
      uid: uid,
      petId: petId,
      measuredAt: DateTime(2026, 7, 15),
      weightKg: 12.4,
    );
    await repository.delete(uid, record);
    final snap = await firestore
        .collection('users/$uid/pets/$petId/weight_records')
        .doc(record.weightId)
        .get();
    expect(snap.exists, isFalse);
  });
}
