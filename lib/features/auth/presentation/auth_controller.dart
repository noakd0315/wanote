import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Wires AuthRepository + UserAccountRepository + PetProfileRepository +
/// BiometricService together with the pure domain resolvers
/// (AuthGateResolver / BiometricFallbackResolver / ActivePetResolver) into a
/// single ChangeNotifier the presentation layer can drive with provider.
///
/// This is the only class in features/auth that talks to all the repos at
/// once; screens should only ever depend on this controller, never on the
/// repositories directly, so the wiring stays in one testable place.
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required UserAccountRepository userAccountRepository,
    required PetProfileRepository petProfileRepository,
    required BiometricService biometricService,
    AuthGateResolver authGateResolver = const AuthGateResolver(),
    BiometricFallbackResolver biometricFallbackResolver =
        const BiometricFallbackResolver(),
    ActivePetResolver activePetResolver = const ActivePetResolver(),
    Future<SharedPreferences>? sharedPreferences,
  }) : _authRepository = authRepository,
       _userAccountRepository = userAccountRepository,
       _petProfileRepository = petProfileRepository,
       _biometricService = biometricService,
       _authGateResolver = authGateResolver,
       _biometricFallbackResolver = biometricFallbackResolver,
       _activePetResolver = activePetResolver,
       _prefsFuture = sharedPreferences ?? SharedPreferences.getInstance();

  static const _lastActivePetIdPrefsKey = 'auth.last_active_pet_id';

  final AuthRepository _authRepository;
  final UserAccountRepository _userAccountRepository;
  final PetProfileRepository _petProfileRepository;
  final BiometricService _biometricService;
  final AuthGateResolver _authGateResolver;
  final BiometricFallbackResolver _biometricFallbackResolver;
  final ActivePetResolver _activePetResolver;
  final Future<SharedPreferences> _prefsFuture;

  StreamSubscription<AuthIdentity?>? _authSub;
  StreamSubscription<List<PetProfile>>? _petsSub;

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

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  Future<void> _onAuthChanged(AuthIdentity? identity) async {
    if (identity == null) {
      await _petsSub?.cancel();
      _petsSub = null;
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
    );
    _pendingBiometricFallback = null;
    _subscribeToPets(identity.uid);

    _isLoading = false;
    notifyListeners();
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
    _errorMessage = null;
    notifyListeners();
    try {
      final identity = await action();
      await _onAuthChanged(identity);
    } catch (e) {
      _errorMessage = e.toString();
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
    super.dispose();
  }
}
