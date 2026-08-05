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

  /// Claims the account's single active session for whichever device just
  /// signed in (PM request: prevent staying signed in on multiple devices
  /// at once). Overwrites any previous [sessionId].
  Future<void> setActiveSession({
    required String uid,
    required String sessionId,
  });

  /// Live `active_session_id` value, so a signed-in device can notice when
  /// a *different* device claims the session (see [setActiveSession]) and
  /// sign itself out. Null until a session has ever been claimed.
  Stream<String?> watchActiveSessionId(String uid);
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

  @override
  Future<void> setActiveSession({
    required String uid,
    required String sessionId,
  }) async {
    // set(merge:) rather than update() -- on a brand-new sign-up this runs
    // (from AuthController._runAuthAction, via _claimSession) *before*
    // getOrCreate() has had a chance to create the user's account doc, so
    // update() would throw NOT_FOUND. merge:true creates the doc with just
    // this field if it doesn't exist yet, and getOrCreate()'s later
    // existence check/creation is unaffected either way.
    await _doc(
      uid,
    ).set({'active_session_id': sessionId}, SetOptions(merge: true));
  }

  @override
  Stream<String?> watchActiveSessionId(String uid) {
    return _doc(
      uid,
    ).snapshots().map((snap) => snap.data()?['active_session_id'] as String?);
  }
}
