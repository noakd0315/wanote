import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firestore_paths.dart';

/// Deletes every Firestore document belonging to one account.
abstract class AccountDocumentEraser {
  /// Removes everything under `users/{uid}` that the client is allowed to
  /// delete, finishing with the account document itself.
  ///
  /// Idempotent: running it again after a partial failure deletes whatever
  /// is left, which is the whole recovery story for a deletion that dies
  /// halfway (see [AccountDeletionService]).
  Future<void> erase(String uid);
}

class FirestoreAccountDocumentEraser implements AccountDocumentEraser {
  FirestoreAccountDocumentEraser({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Firestore caps a batch at 500 writes; stay under it with room to spare.
  static const _batchSize = 400;

  @override
  Future<void> erase(String uid) async {
    // Deleting a document does NOT delete its subcollections -- they simply
    // become unreachable orphans that still exist, still cost storage, and
    // still contain the user's data. There is no recursive delete in the
    // client SDK, so the tree has to be walked explicitly, deepest first.
    final pets = await _firestore.collection(FirestorePaths.pets(uid)).get();
    for (final pet in pets.docs) {
      for (final name in FirestorePaths.petSubcollectionNames) {
        await _eraseCollection('${FirestorePaths.pet(uid, pet.id)}/$name');
      }
    }

    for (final name in FirestorePaths.ownedAccountSubcollectionNames) {
      await _eraseCollection('${FirestorePaths.user(uid)}/$name');
    }

    await _firestore.doc(FirestorePaths.user(uid)).delete();
  }

  /// Deletes every document in [path], a page at a time so a long history of
  /// daily records can't blow the batch limit or a single query's memory.
  Future<void> _eraseCollection(String path) async {
    while (true) {
      final snapshot = await _firestore
          .collection(path)
          .limit(_batchSize)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // A short page means that was the last one; re-querying would only
      // cost another round trip to learn the same thing.
      if (snapshot.docs.length < _batchSize) return;
    }
  }
}
