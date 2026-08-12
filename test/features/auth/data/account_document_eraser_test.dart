import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/auth/data/account_document_eraser.dart';
import 'package:wanote/shared/firestore_paths.dart';

/// Account deletion's Firestore sweep.
///
/// The failure mode this guards against is silent: Firestore does not delete
/// a document's subcollections when the document goes, so an incomplete walk
/// leaves the user's medical records sitting in the database while the app
/// shows nothing at all. Nobody would notice from the UI, which is why the
/// coverage here is about what is *left* rather than what the code did.
void main() {
  const uid = 'owner-uid';
  const otherUid = 'someone-else';

  late FakeFirebaseFirestore firestore;
  late FirestoreAccountDocumentEraser eraser;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    eraser = FirestoreAccountDocumentEraser(firestore: firestore);
  });

  Future<void> seedAccount(String owner, {int pets = 1}) async {
    await firestore.doc(FirestorePaths.user(owner)).set({'email': 'a@b.test'});
    for (var i = 0; i < pets; i++) {
      final petId = 'pet-$i';
      await firestore.doc(FirestorePaths.pet(owner, petId)).set({
        'pet_name': 'Pochi',
      });
      for (final name in FirestorePaths.petSubcollectionNames) {
        await firestore
            .collection('${FirestorePaths.pet(owner, petId)}/$name')
            .doc('doc-1')
            .set({'seeded': true});
      }
    }
    await firestore
        .collection(FirestorePaths.usageCounters(owner))
        .doc('2026-08')
        .set({'count': 3});
  }

  Future<int> countDocsUnder(String owner) async {
    var total = 0;
    final user = await firestore.doc(FirestorePaths.user(owner)).get();
    if (user.exists) total++;
    final pets = await firestore.collection(FirestorePaths.pets(owner)).get();
    total += pets.docs.length;
    for (final pet in pets.docs) {
      for (final name in FirestorePaths.petSubcollectionNames) {
        final sub = await firestore
            .collection('${FirestorePaths.pet(owner, pet.id)}/$name')
            .get();
        total += sub.docs.length;
      }
    }
    final counters = await firestore
        .collection(FirestorePaths.usageCounters(owner))
        .get();
    total += counters.docs.length;
    return total;
  }

  test('leaves nothing behind under the account', () async {
    await seedAccount(uid, pets: 2);
    expect(await countDocsUnder(uid), greaterThan(0));

    await eraser.erase(uid);

    expect(await countDocsUnder(uid), 0);
  });

  test('removes every pet subcollection, not just the pet document', () async {
    // The one that would rot quietly: deleting `pets/{petId}` makes the pet
    // vanish from the app while its health, weight, toilet, visit,
    // medication, prevention, consultation and report documents all still
    // exist -- unreachable, but stored, and full of the user's data.
    await seedAccount(uid);

    await eraser.erase(uid);

    for (final name in FirestorePaths.petSubcollectionNames) {
      final remaining = await firestore
          .collection('${FirestorePaths.pet(uid, 'pet-0')}/$name')
          .get();
      expect(remaining.docs, isEmpty, reason: '$name survived deletion');
    }
  });

  test('does not touch another account', () async {
    await seedAccount(uid);
    await seedAccount(otherUid);

    await eraser.erase(uid);

    expect(await countDocsUnder(otherUid), greaterThan(0));
  });

  test('is safe to run again after a partial failure', () async {
    // Deleting the identity happens last precisely so that a run which dies
    // part-way can be retried. That only helps if the retry is harmless.
    await seedAccount(uid);
    await eraser.erase(uid);

    await expectLater(eraser.erase(uid), completes);
    expect(await countDocsUnder(uid), 0);
  });

  test('erases an account that has no pets at all', () async {
    // Someone who signs up and immediately changes their mind never gets
    // past the account document.
    await firestore.doc(FirestorePaths.user(uid)).set({'email': 'a@b.test'});

    await eraser.erase(uid);

    expect((await firestore.doc(FirestorePaths.user(uid)).get()).exists, false);
  });

  test('pages through a collection larger than one batch', () async {
    // Firestore caps a batch at 500 writes, and a daily record kept for a
    // few years passes that. The loop has to keep going rather than stop at
    // the first page.
    await firestore.doc(FirestorePaths.user(uid)).set({'email': 'a@b.test'});
    await firestore.doc(FirestorePaths.pet(uid, 'pet-0')).set({
      'pet_name': 'P',
    });
    final records = firestore.collection(
      FirestorePaths.healthRecords(uid, 'pet-0'),
    );
    for (var i = 0; i < 901; i++) {
      await records.doc('r$i').set({'i': i});
    }

    await eraser.erase(uid);

    expect((await records.get()).docs, isEmpty);
  });
}
