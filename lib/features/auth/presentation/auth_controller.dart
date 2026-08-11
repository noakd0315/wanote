import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/app_user.dart';
import '../../../shared/models/auth_provider_type.dart';
import '../../../shared/models/pet_profile.dart';
import '../data/auth_repository.dart';
import '../data/biometric_service.dart';
import '../data/pet_profile_repository.dart';
import '../data/user_account_repository.dart';
import '../domain/active_pet_resolver.dart';
import '../domain/auth_gate_resolver.dart';
import '../domain/biometric_fallback_resolver.dart';
import '../domain/session_expiry_policy.dart';

/// Wires AuthRepository + UserAccountRepository + PetProfileRepository +
/// BiometricService together with the pure domain resolvers
/// (AuthGateResolver / BiometricFallbackResolver / ActivePetResolver) into a
/// single ChangeNotifier the presentation layer can drive with provider.
///
/// This is the only class in features/auth that talks to all the repos at
/// once; screens should only ever depend on this controller, never on the
/// repositories directly, so the wiring stays in one testable place.
class AuthController extends ChangeNotifier {
  // The private initializing formals below are still passed by their public
  // names at the call site (`authRepository:` and so on) -- Dart derives those
  // automatically. `sharedPreferences` cannot join them because it is
  // transformed rather than stored as given.
  AuthController({
    required this._authRepository,
    required this._userAccountRepository,
    required this._petProfileRepository,
    required this._biometricService,
    this._authGateResolver = const AuthGateResolver(),
    this._sessionExpiryPolicy = const SessionExpiryPolicy(),
    DateTime Function()? now,
    this._biometricFallbackResolver = const BiometricFallbackResolver(),
    this._activePetResolver = const ActivePetResolver(),
    Future<SharedPreferences>? sharedPreferences,
  }) : _prefsFuture = sharedPreferences ?? SharedPreferences.getInstance(),
       _now = now ?? DateTime.now;

  static const _lastActivePetIdPrefsKey = 'auth.last_active_pet_id';

  /// Prefix for the per-uid key this device's own claimed session id is
  /// stored under (see [_subscribeToSession]'s doc comment). Keyed by uid
  /// rather than a single global key so switching accounts on the same
  /// device/browser doesn't confuse one account's session for another's.
  static const _localSessionIdPrefsKeyPrefix = 'auth.local_session_id.';

  /// When this device last saw the user prove who they are -- an explicit
  /// sign-in or a successful biometric unlock. Per-uid so switching accounts
  /// on one device doesn't inherit the other's freshness. See
  /// [SessionExpiryPolicy]; deliberately NOT updated by merely resuming a
  /// persisted session.
  static const _lastAuthenticatedAtPrefsKeyPrefix =
      'auth.last_authenticated_at.';

  final Uuid _uuid = const Uuid();

  final AuthRepository _authRepository;
  final UserAccountRepository _userAccountRepository;
  final PetProfileRepository _petProfileRepository;
  final BiometricService _biometricService;
  final AuthGateResolver _authGateResolver;
  final SessionExpiryPolicy _sessionExpiryPolicy;

  /// Injectable clock, so session expiry can be tested without waiting a day.
  final DateTime Function() _now;
  final BiometricFallbackResolver _biometricFallbackResolver;
  final ActivePetResolver _activePetResolver;
  final Future<SharedPreferences> _prefsFuture;

  /// Bumped by [_claimSession]; captured by [_subscribeToSession] so a
  /// subscription opened before a claim can tell that it is now stale.
  int _sessionGeneration = 0;

  StreamSubscription<AuthIdentity?>? _authSub;
  StreamSubscription<List<PetProfile>>? _petsSub;
  StreamSubscription<String?>? _sessionSub;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  AuthGateAction _gateAction = AuthGateAction.requireSignIn;
  AuthGateAction get gateAction => _gateAction;

  List<PetProfile> _pets = const [];
  List<PetProfile> get pets => _pets;

  PetProfile? _activePet;
  PetProfile? get activePet => _activePet;

  bool _biometricAvailable = false;
  bool get biometricAvailable => _biometricAvailable;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// A stable machine code identifying the last sign-in/sign-up failure
  /// (e.g. Firebase Auth's `e.code`, like 'email-already-in-use'), *not*
  /// the raw exception text -- PM report: raw SDK error messages (English,
  /// sometimes internal-implementation-detail-laden, e.g. a Firestore
  /// NOT_FOUND dump) were showing directly on the sign-in screen. The full
  /// exception is logged for developers via [developer.log] in
  /// [_runAuthAction]'s catch block instead; the UI maps this code to a
  /// friendly localized message (see sign_up_screen.dart's
  /// _authErrorMessage), falling back to a generic "something went wrong"
  /// string for codes it doesn't recognize.
  String? _errorCode;
  String? get errorCode => _errorCode;

  /// Set once when [_subscribeToSession] notices a different device has
  /// taken over this account and forces a local sign-out (PM request:
  /// prevent staying signed in on multiple devices at once). Deliberately a
  /// bare flag, not the message text itself -- this controller has no
  /// BuildContext to localize with, so the sign-in screen supplies the
  /// actual (localized) copy once it sees this flag, via
  /// [clearForcedSignOutFlag].
  bool _wasForcedSignedOut = false;
  bool get wasForcedSignedOut => _wasForcedSignedOut;

  void clearForcedSignOutFlag() {
    _wasForcedSignedOut = false;
  }

  /// True from the moment a brand-new account is created until
  /// [markOnboardingComplete] is called. Drives the one-time post-
  /// registration flow (biometric setup -> first pet profile) that
  /// LaunchGateScreen layers on top of the returning-user [gateAction].
  bool _justRegistered = false;
  bool get justRegistered => _justRegistered;

  BiometricFallbackAction? _pendingBiometricFallback;
  BiometricFallbackAction? get pendingBiometricFallback =>
      _pendingBiometricFallback;

  /// Must be called once (e.g. from a top-level FutureBuilder in main.dart)
  /// before the controller is used. Subscribes to the Firebase Auth session
  /// stream and determines the initial gate action.
  Future<void> initialize() async {
    _biometricAvailable = await _biometricService.isAvailable();
    _authSub = _authRepository.authStateChanges().listen(_onAuthChanged);
    await _onAuthChanged(_authRepository.currentUser);
  }

  /// [claimSession] is set only by [_runAuthAction] -- i.e. when this device
  /// is *explicitly* signing in right now, as opposed to the auth stream
  /// merely replaying an already-persisted session on app restart. See
  /// [_claimSession] for why the claim has to happen inside here rather than
  /// after this method returns.
  Future<void> _onAuthChanged(
    AuthIdentity? identity, {
    bool claimSession = false,
  }) async {
    if (identity == null) {
      await _petsSub?.cancel();
      _petsSub = null;
      await _sessionSub?.cancel();
      _sessionSub = null;
      _currentUser = null;
      _pets = const [];
      _activePet = null;
      _pendingBiometricFallback = null;
      _gateAction = _authGateResolver.resolve(
        hasActiveSession: false,
        biometricEnabled: false,
        biometricAvailable: _biometricAvailable,
      );
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Distinguish "brand-new account" from "returning session" by checking
    // whether the Firestore account doc already existed, rather than by
    // which sign-in method was called - Google/Apple use the same
    // signInWith* call for first-time and returning users.
    final existing = await _userAccountRepository.get(identity.uid);
    final isNewAccount = existing == null;
    final user =
        existing ??
        await _userAccountRepository.getOrCreate(
          uid: identity.uid,
          email: identity.email,
          provider: identity.provider,
        );

    _currentUser = user;
    if (isNewAccount) {
      _justRegistered = true;
    }
    _gateAction = _authGateResolver.resolve(
      hasActiveSession: true,
      biometricEnabled: user.biometricEnabled,
      biometricAvailable: _biometricAvailable,
      sessionExpired: await _isSessionExpired(identity.uid),
    );
    _pendingBiometricFallback = null;
    _subscribeToPets(identity.uid);
    // Claim BEFORE subscribing, never after: watchActiveSessionId() replays
    // the account doc's *current* active_session_id to every new listener,
    // so subscribing first would deliver the previous session's id while
    // _claimSession had already overwritten the local copy with the new one
    // -- the device would then compare new-local against stale-remote, decide
    // another device had taken over, and sign itself out immediately after a
    // perfectly good sign-in (PM report: "ログイン後ブラウザバック等でログイン
    // 画面に戻った場合、正しいパスワードを入力してもエラーになってしまいます").
    // Only the *second* sign-in was affected, because on a brand-new account
    // the replayed value is null, which _subscribeToSession ignores.
    if (claimSession) {
      await _claimSession(identity.uid);
    }
    _subscribeToSession(identity.uid);

    _isLoading = false;
    notifyListeners();
  }

  /// Watches this account's `active_session_id` and signs this device out
  /// the moment a *different* device claims it (see [_claimSession] --
  /// called by every explicit sign-in action) -- PM report: multiple
  /// devices could stay signed in to the same account simultaneously,
  /// which shouldn't be allowed.
  ///
  /// The very first value this device ever sees for an account (no local
  /// copy yet -- e.g. this feature shipping after the account already had
  /// an active session elsewhere, or this being the device that *just*
  /// claimed it) is adopted rather than treated as a foreign device, so it
  /// never spuriously signs itself out.
  void _subscribeToSession(String uid) {
    _sessionSub?.cancel();
    // Snapshots that were generated before this device's most recent claim
    // are stale by definition and must never be read as a takeover. Firebase
    // Auth fires authStateChanges() as part of a successful sign-in, so
    // _onAuthChanged (and therefore this method) runs twice, concurrently,
    // for a single sign-in; without this guard the stream-driven
    // subscription can replay the *previous* session id after
    // _claimSession has already stored the new one locally, and the device
    // signs itself out right after signing in.
    final generation = _sessionGeneration;
    _sessionSub = _userAccountRepository.watchActiveSessionId(uid).listen((
      remoteSessionId,
    ) async {
      if (generation != _sessionGeneration) return;
      if (remoteSessionId == null) return;
      final prefs = await _prefsFuture;
      final key = '$_localSessionIdPrefsKeyPrefix$uid';
      final localSessionId = prefs.getString(key);
      if (localSessionId == null) {
        await prefs.setString(key, remoteSessionId);
        return;
      }
      if (localSessionId != remoteSessionId) {
        _wasForcedSignedOut = true;
        await signOut();
      }
    });
  }

  /// Claims the account's single active session for this device, called by
  /// every explicit sign-in action ([signUpWithEmail]/[signInWithEmail]/
  /// [signInWithGoogle]/[signInWithApple] via [_runAuthAction]) -- but not
  /// on an ordinary app restart resuming an already-persisted session,
  /// since that's the same device continuing, not a new one taking over.
  ///
  /// The remote copy is written *before* the local one, and the order
  /// matters: these are two separate writes and the app can die between them
  /// (a browser tab killed for memory is the case that prompted this). Remote
  /// first means a crash in the gap leaves the account already claimed, so the
  /// previously signed-in device still gets kicked out and this one merely has
  /// to sign in again. Local first would leave the remote copy pointing at the
  /// *old* device -- the takeover would silently fail and the old device would
  /// stay signed in, which is the one outcome this feature exists to prevent.
  /// Whether this device has gone longer than [SessionExpiryPolicy.maxAge]
  /// without the user proving who they are.
  Future<bool> _isSessionExpired(String uid) async {
    final prefs = await _prefsFuture;
    final stored = prefs.getString('$_lastAuthenticatedAtPrefsKeyPrefix$uid');
    final lastAuthenticatedAt = stored == null
        ? null
        : DateTime.tryParse(stored);
    return _sessionExpiryPolicy.hasExpired(
      lastAuthenticatedAt: lastAuthenticatedAt,
      now: _now(),
    );
  }

  /// Records that the user just proved who they are, restarting the window.
  ///
  /// Called on explicit sign-in and on a successful biometric unlock -- both
  /// are real proof. Never called when a persisted session is merely
  /// resumed, or opening the app daily would keep the window open forever.
  Future<void> _recordAuthentication(String uid) async {
    final prefs = await _prefsFuture;
    await prefs.setString(
      '$_lastAuthenticatedAtPrefsKeyPrefix$uid',
      _now().toIso8601String(),
    );
  }

  /// Re-evaluates the gate for an already-signed-in user, so a session that
  /// ages out while the app sits in the background is caught on resume
  /// rather than only at a cold start.
  Future<void> refreshSessionGate() async {
    final user = _currentUser;
    if (user == null || _gateAction != AuthGateAction.enterApp) return;
    final expired = await _isSessionExpired(user.uid);
    if (!expired) return;
    _gateAction = _authGateResolver.resolve(
      hasActiveSession: true,
      biometricEnabled: user.biometricEnabled,
      biometricAvailable: _biometricAvailable,
      sessionExpired: true,
    );
    if (_gateAction == AuthGateAction.requireSignIn) {
      await signOut();
      return;
    }
    notifyListeners();
  }

  Future<void> _claimSession(String uid) async {
    // Invalidates every session subscription created before this point --
    // see _subscribeToSession.
    _sessionGeneration++;
    final sessionId = _uuid.v4();
    final prefs = await _prefsFuture;
    await _userAccountRepository.setActiveSession(
      uid: uid,
      sessionId: sessionId,
    );
    await prefs.setString('$_localSessionIdPrefsKeyPrefix$uid', sessionId);
  }

  void _subscribeToPets(String uid) {
    _petsSub?.cancel();
    _petsSub = _petProfileRepository.watchPets(uid).listen((pets) async {
      _pets = pets;
      final prefs = await _prefsFuture;
      final previousActiveId =
          _activePet?.petId ?? prefs.getString(_lastActivePetIdPrefsKey);
      final resolvedId = _activePetResolver.resolve(
        petIds: pets.map((p) => p.petId).toList(),
        previousActiveId: previousActiveId,
      );
      if (resolvedId == null) {
        _activePet = null;
      } else {
        final match = pets.where((p) => p.petId == resolvedId);
        _activePet = match.isEmpty ? null : match.first;
        await prefs.setString(_lastActivePetIdPrefsKey, resolvedId);
      }
      notifyListeners();
    });
  }

  Future<void> _runAuthAction(Future<AuthIdentity> Function() action) async {
    _isLoading = true;
    _errorCode = null;
    notifyListeners();
    try {
      final identity = await action();
      // This device is actively signing in right now (as opposed to
      // _onAuthChanged firing from a merely-resumed persisted session on
      // app restart), so it claims the account's single active session --
      // see _claimSession's doc comment. The claim happens *inside*
      // _onAuthChanged, sequenced after getOrCreate() (so the account doc
      // already exists) but before the session watcher is attached (so the
      // watcher never replays a stale session id); doing it out here on
      // either side of this call reintroduces one bug or the other.
      await _recordAuthentication(identity.uid);
      await _onAuthChanged(identity, claimSession: true);
    } catch (e, stackTrace) {
      // Full exception -> developer-facing log only (PM report: raw SDK
      // error text, e.g. "[cloud_firestore/not-found] NOT_FOUND: no
      // entity to update: app: ..." was showing directly on the sign-in
      // screen). _errorCode is just the stable machine code the UI maps
      // to a friendly localized message.
      developer.log(
        'Auth action failed',
        name: 'AuthController',
        error: e,
        stackTrace: stackTrace,
      );
      _errorCode = e is fb.FirebaseAuthException ? e.code : 'unknown';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) => _runAuthAction(
    () => _authRepository.signUpWithEmail(email: email, password: password),
  );

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _runAuthAction(
    () => _authRepository.signInWithEmail(email: email, password: password),
  );

  /// Not routed through [_runAuthAction] -- this doesn't change auth state
  /// (no identity comes back, gateAction stays whatever it was), it's a
  /// plain side-effecting call the sign-in screen awaits directly to show
  /// its own success/error message.
  Future<void> sendPasswordResetEmail(String email) =>
      _authRepository.sendPasswordResetEmail(email);

  Future<void> signInWithGoogle() =>
      _runAuthAction(_authRepository.signInWithGoogle);

  Future<void> signInWithApple() =>
      _runAuthAction(_authRepository.signInWithApple);

  Future<void> signOut() async {
    await _authRepository.signOut();
    // The authStateChanges listener fires with null and clears state via
    // _onAuthChanged; no need to duplicate that logic here.
  }

  /// Runs a single biometric prompt attempt and resolves what should happen
  /// next via BiometricFallbackResolver. Sets [gateAction] to enterApp on
  /// success, or populates [pendingBiometricFallback] on failure so the UI
  /// can render the right fallback (retry / re-enter password / redo
  /// provider sign-in).
  Future<void> promptBiometric({String reason = 'Unlock wanote'}) async {
    final result = await _biometricService.authenticate(reason: reason);
    if (result == BiometricPromptResult.success) {
      _pendingBiometricFallback = null;
      // The biometric prompt IS the re-authentication for this window, so
      // passing it restarts the clock (PM: biometric may pass instead of a
      // full sign-out).
      final uid = _currentUser?.uid;
      if (uid != null) await _recordAuthentication(uid);
      _gateAction = AuthGateAction.enterApp;
      notifyListeners();
      return;
    }
    final provider = _currentUser?.authProvider ?? AuthProviderType.email;
    _pendingBiometricFallback = _biometricFallbackResolver.resolve(
      result: result,
      provider: provider,
    );
    notifyListeners();
  }

  /// Fallback path for email/password accounts (spec 1.2/1.4): re-verify the
  /// app password instead of the OS biometric prompt.
  Future<void> completeReenterPassword(String password) async {
    await _authRepository.reauthenticateWithPassword(password);
    _pendingBiometricFallback = null;
    final uid = _currentUser?.uid;
    if (uid != null) await _recordAuthentication(uid);
    _gateAction = AuthGateAction.enterApp;
    notifyListeners();
  }

  /// Fallback path for Apple/Google accounts, which have no app password:
  /// redo that provider's sign-in flow instead.
  Future<void> completeReauthenticateWithProvider() async {
    final provider = _currentUser?.authProvider;
    switch (provider) {
      case AuthProviderType.google:
        await _authRepository.signInWithGoogle();
      case AuthProviderType.apple:
        await _authRepository.signInWithApple();
      case AuthProviderType.email:
      case null:
        throw StateError(
          'completeReauthenticateWithProvider is only valid for Google or Apple accounts.',
        );
    }
    _pendingBiometricFallback = null;
    _gateAction = AuthGateAction.enterApp;
    notifyListeners();
  }

  /// A plain biometric mismatch: let the caller re-show the prompt.
  Future<void> retryBiometric({String reason = 'Unlock wanote'}) =>
      promptBiometric(reason: reason);

  /// Persists the "biometric_enabled" toggle to Firestore via
  /// UserAccountRepository (account-level setting, spec 1.3).
  Future<void> setBiometricEnabled(bool enabled) async {
    final user = _currentUser;
    if (user == null) return;
    await _userAccountRepository.setBiometricEnabled(user.uid, enabled);
    _currentUser = user.copyWith(biometricEnabled: enabled);
    notifyListeners();
  }

  /// Ends the one-time post-registration onboarding flow (called after the
  /// biometric-setup screen is dismissed, whether enabled or skipped).
  void markOnboardingComplete() {
    _justRegistered = false;
    notifyListeners();
  }

  Future<PetProfile> createPet({
    required String name,
    required String breed,
    required DateTime birthday,
    required PetSex sex,
    required bool neutered,
    double? weightKg,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    final pet = await _petProfileRepository.create(
      ownerId: uid,
      name: name,
      breed: breed,
      birthday: birthday,
      sex: sex,
      neutered: neutered,
      weightKg: weightKg,
    );
    await switchActivePet(pet.petId);
    return pet;
  }

  Future<void> updatePet(PetProfile pet) => _petProfileRepository.update(pet);

  /// Uploads [bytes] as [petId]'s profile photo and returns the download
  /// URL. Callers must still persist the URL onto the pet via [updatePet]
  /// (e.g. `pet.copyWith(photoUrl: url)`) -- a brand-new pet has no id
  /// until [createPet] returns, so the form screen uploads as a follow-up
  /// step, same two-step pattern as the prevention-certificate flow.
  Future<String> uploadPetPhoto({
    required String petId,
    required Uint8List bytes,
  }) {
    final uid = _currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return _petProfileRepository.uploadPhoto(
      ownerId: uid,
      petId: petId,
      bytes: bytes,
    );
  }

  /// Same as [uploadPetPhoto] but for the separate icon/avatar image (PM
  /// request: "愛犬アイコンと背景は別々の画像を設定できるようにしたい").
  Future<String> uploadPetIconPhoto({
    required String petId,
    required Uint8List bytes,
  }) {
    final uid = _currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return _petProfileRepository.uploadPhoto(
      ownerId: uid,
      petId: petId,
      bytes: bytes,
      fileName: 'profile_icon.jpg',
    );
  }

  /// Deletes the background photo's Storage object (PM request: "愛犬の写真
  /// を削除する機能を追加したい"). Callers still need to persist
  /// `pet.copyWith(clearPhotoUrl: true)` via [updatePet].
  Future<void> deletePetPhoto(String petId) {
    final uid = _currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return _petProfileRepository.deletePhoto(ownerId: uid, petId: petId);
  }

  /// Same as [deletePetPhoto] but for the separate icon/avatar image.
  Future<void> deletePetIconPhoto(String petId) {
    final uid = _currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return _petProfileRepository.deletePhoto(
      ownerId: uid,
      petId: petId,
      fileName: 'profile_icon.jpg',
    );
  }

  Future<void> deletePet(String petId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _petProfileRepository.delete(uid, petId);
    // _subscribeToPets' listener will re-run ActivePetResolver once the
    // Firestore stream emits the post-delete list.
  }

  Future<void> switchActivePet(String petId) async {
    final match = _pets.where((p) => p.petId == petId);
    if (match.isEmpty) return;
    _activePet = match.first;
    final prefs = await _prefsFuture;
    await prefs.setString(_lastActivePetIdPrefsKey, petId);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _petsSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }
}
