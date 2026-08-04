import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../shared/models/auth_provider_type.dart';

/// Thin identity result returned by [AuthRepository]. Account-level fields
/// that live in Firestore (biometric_enabled, etc.) are handled separately by
/// `UserAccountRepository` — this repository only wraps Firebase Auth.
class AuthIdentity {
  const AuthIdentity({
    required this.uid,
    required this.email,
    required this.provider,
  });

  final String uid;
  final String email;
  final AuthProviderType provider;
}

/// Wraps Firebase Auth so the rest of the feature never imports
/// `firebase_auth` directly, keeping domain/presentation code testable with a
/// fake implementation.
abstract class AuthRepository {
  Stream<AuthIdentity?> authStateChanges();

  AuthIdentity? get currentUser;

  Future<AuthIdentity> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<AuthIdentity> signInWithEmail({
    required String email,
    required String password,
  });

  /// Re-verifies the current email/password user's password. Used as the
  /// biometric-failure fallback for email accounts (spec 1.4).
  Future<void> reauthenticateWithPassword(String password);

  Future<AuthIdentity> signInWithGoogle();

  Future<AuthIdentity> signInWithApple();

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthIdentity? _toIdentity(fb.User? user) {
    if (user == null) return null;
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';
    final provider = switch (providerId) {
      'google.com' => AuthProviderType.google,
      'apple.com' => AuthProviderType.apple,
      _ => AuthProviderType.email,
    };
    return AuthIdentity(
      uid: user.uid,
      email: user.email ?? '',
      provider: provider,
    );
  }

  @override
  Stream<AuthIdentity?> authStateChanges() {
    return _auth.authStateChanges().map(_toIdentity);
  }

  @override
  AuthIdentity? get currentUser => _toIdentity(_auth.currentUser);

  @override
  Future<AuthIdentity> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toIdentity(credential.user)!;
  }

  @override
  Future<AuthIdentity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toIdentity(credential.user)!;
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in email/password user to reauthenticate.');
    }
    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<AuthIdentity> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return _toIdentity(userCredential.user)!;
  }

  @override
  Future<AuthIdentity> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oAuthCredential = fb.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final userCredential = await _auth.signInWithCredential(oAuthCredential);
    return _toIdentity(userCredential.user)!;
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
