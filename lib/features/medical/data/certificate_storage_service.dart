import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a certificate image (spec 5.3's `certificate_file`) to Firebase
/// Storage under a per-user/per-pet path so Storage security rules can
/// restrict access to the owning user only (spec 5.5's "他ユーザーから閲覧
/// できないこと" requirement — enforced in storage.rules, not in this
/// client code).
abstract class CertificateStorageService {
  /// Uploads [bytes] and returns its public download URL to store as
  /// `certificate_file`.
  Future<String> upload({
    required String uid,
    required String petId,
    required String recordId,
    required Uint8List bytes,
    required String contentType,
  });

  /// Removes the image for [recordId], if there is one.
  ///
  /// Deleting a prevention record used to remove only the Firestore document
  /// and leave this file behind. A certificate is a photograph of a document
  /// carrying a clinic name and often the owner's, and the privacy policy
  /// states that records can be deleted -- so leaving it was both a broken
  /// promise and the more sensitive image of the two.
  Future<void> delete({
    required String uid,
    required String petId,
    required String recordId,
  });
}

class FirebaseCertificateStorageService implements CertificateStorageService {
  FirebaseCertificateStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// The path is derived from the ids, not parsed out of the stored download
  /// URL: those are opaque and signed, and a record whose URL failed to
  /// parse would silently keep its image.
  String _pathFor(String uid, String petId, String recordId) =>
      'users/$uid/pets/$petId/prevention_certificates/$recordId';

  @override
  Future<void> delete({
    required String uid,
    required String petId,
    required String recordId,
  }) async {
    try {
      await _storage.ref(_pathFor(uid, petId, recordId)).delete();
    } on FirebaseException catch (e) {
      // A record saved without a certificate has no file, and that is not a
      // failure. Anything else is rethrown so the caller can decide.
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  @override
  Future<String> upload({
    required String uid,
    required String petId,
    required String recordId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref(_pathFor(uid, petId, recordId));
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
