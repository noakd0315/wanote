import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firestore_paths.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/auth_provider_type.dart';

/// Persists the account-level fields from spec 1.3 (email, auth_provider,
/// biometric_enabled) that don't live on the Firebase Auth user object.
abstract class UserAccountRepository {
  Future<AppUser> getOrCreate({
    required String uid,
    required String email,
    required AuthProviderType provider,
  });

  Future<AppUser?> get(String uid);

  Future<void> setBiometricEnabled(String uid, bool enabled);
}

class FirestoreUserAccountRepository implements UserAccountRepository {
  FirestoreUserAccountRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.doc(FirestorePaths.user(uid));

  @override
  Future<AppUser> getOrCreate({
    required String uid,
    required String email,
    required AuthProviderType provider,
  }) async {
    final snapshot = await _doc(uid).get();
    if (snapshot.exists) {
      return AppUser.fromMap(snapshot.data()!);
    }
    final user = AppUser(
      uid: uid,
      email: email,
      authProvider: provider,
      biometricEnabled: false,
    );
    await _doc(uid).set(user.toMap());
    return user;
  }

  @override
  Future<AppUser?> get(String uid) async {
    final snapshot = await _doc(uid).get();
    if (!snapshot.exists) return null;
    return AppUser.fromMap(snapshot.data()!);
  }

  @override
  Future<void> setBiometricEnabled(String uid, bool enabled) async {
    await _doc(uid).update({'biometric_enabled': enabled});
  }
}
