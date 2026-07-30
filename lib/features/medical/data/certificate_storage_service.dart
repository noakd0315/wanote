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
}

class FirebaseCertificateStorageService implements CertificateStorageService {
  FirebaseCertificateStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> upload({
    required String uid,
    required String petId,
    required String recordId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref(
      'users/$uid/pets/$petId/prevention_certificates/$recordId',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
