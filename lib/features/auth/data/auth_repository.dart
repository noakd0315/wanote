import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../shared/models/auth_provider_type.dart';
import '../../../shared/config/app_config.dart';

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

  /// Sends a password-reset email (spec gap the PM flagged after locking
  /// themselves out of a test account: "パスワードを忘れてしまった場合の
  /// 対処"). In the local emulator this doesn't deliver a real email, but
  /// the same call sends a genuine reset email once a real Firebase project
  /// is configured.
  Future<void> sendPasswordResetEmail(String email);

  /// Re-verifies the current email/password user's password. Used as the
  /// biometric-failure fallback for email accounts (spec 1.4).
  Future<void> reauthenticateWithPassword(String password);

  Future<AuthIdentity> signInWithGoogle();

  Future<AuthIdentity> signInWithApple();

  Future<void> signOut();

  /// Permanently deletes the signed-in Firebase Auth user.
  ///
  /// Firebase rejects this with `requires-recent-login` unless the user
  /// authenticated recently, which is why the deletion flow reauthenticates
  /// first (see [AuthController.deleteAccount]).
  ///
  /// This must be the *last* step of account deletion. Both firestore.rules
  /// and storage.rules key off `request.auth.uid`, so once the identity is
  /// gone nothing can reach that account's documents or files again -- any
  /// data still behind would be stranded with no way to delete it.
  Future<void> deleteCurrentUser();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
       // google_sign_in 7 removed the public constructor: there is now a
       // single process-wide instance that must be initialize()d once before
       // any sign-in attempt (see _ensureGoogleInitialized).
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<void>? _googleInitialization;

  /// initialize() is idempotent per process but must complete before
  /// authenticate(); caching the future keeps concurrent sign-in taps from
  /// racing two initializations.
  Future<void> _ensureGoogleInitialized() =>
      _googleInitialization ??= _googleSignIn.initialize();

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
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
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
    await _ensureGoogleInitialized();
    // authenticate() replaces signIn(). It throws on cancellation rather
    // than returning null, so the old null-check is gone.
    final googleUser = await _googleSignIn.authenticate();
    // google_sign_in 7 split authentication from authorization: the account's
    // authentication only carries an ID token now, and accessToken moved to
    // the separate authorizationClient. Firebase only needs the ID token to
    // mint a credential, so there is nothing to authorize here.
    final credential = fb.GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
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
      // Android has no Apple sign-in of its own, so the package runs
      // Apple's web flow -- and that flow will not start without a Services
      // ID and a redirect URI Apple recognises. Without this the button
      // failed on Android while working on iPhone, which asks the OS
      // directly and ignores all of this (PM report, 2026-08-18).
      //
      // Passed on every platform rather than behind a check: iOS does not
      // read it, and a platform test here would be one more thing to get
      // wrong on whatever platform is added next.
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: AppConfig.appleServicesId,
        redirectUri: Uri.parse(AppConfig.appleRedirectUri),
      ),
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

  @override
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to delete.');
    }
    await user.delete();
    // Google keeps its own cached session next to Firebase's; without this a
    // subsequent "sign in with Google" silently reuses the account that was
    // just deleted instead of showing the account chooser.
    await _googleSignIn.signOut();
  }
}
