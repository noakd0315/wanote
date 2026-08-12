import 'account_backend_client.dart';
import 'account_document_eraser.dart';
import 'account_file_eraser.dart';
import 'auth_repository.dart';

/// Erases an account and everything it owns.
///
/// Required by App Store Review Guideline 5.1.1(v) (and Google Play's data
/// deletion policy): an app that lets people create an account must let them
/// delete it from inside the app.
abstract class AccountDeletionService {
  /// Deletes [uid]'s files, documents, server-side billing records and
  /// finally the Firebase Auth identity.
  ///
  /// The caller must have reauthenticated first -- see
  /// `AuthController.deleteAccount`, which is the only intended entry point.
  Future<void> deleteAccount(String uid);
}

class DefaultAccountDeletionService implements AccountDeletionService {
  // Private initializing formals: still passed by their public names
  // (`authRepository:` and so on) at the call site, same as AuthController.
  const DefaultAccountDeletionService({
    required this._authRepository,
    required this._fileEraser,
    required this._documentEraser,
    required this._backendClient,
  });

  final AuthRepository _authRepository;
  final AccountFileEraser _fileEraser;
  final AccountDocumentEraser _documentEraser;
  final AccountBackendClient _backendClient;

  /// The order below is the whole design, and it is not interchangeable.
  ///
  /// Deleting the Firebase Auth user goes **last**. Both firestore.rules and
  /// storage.rules grant access on `request.auth.uid == uid`, and the
  /// Worker's routes authorize off a Firebase ID token, so the identity is
  /// the key to all three. Delete it first and every remaining byte becomes
  /// permanently unreachable: not by the user, not by a retry, not by
  /// support. Deleting it last means any step that fails leaves the account
  /// intact and the whole operation re-runnable -- each step is idempotent
  /// precisely so that retrying is the recovery path.
  ///
  /// Files go before documents so that if it does die halfway, the document
  /// tree -- the only index of what was ever uploaded -- is still there.
  @override
  Future<void> deleteAccount(String uid) async {
    await _fileEraser.erase(uid);
    await _documentEraser.erase(uid);
    await _backendClient.deleteServerData();
    await _authRepository.deleteCurrentUser();
  }
}
