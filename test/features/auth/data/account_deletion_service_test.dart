import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/auth/data/account_backend_client.dart';
import 'package:wanote/features/auth/data/account_deletion_service.dart';
import 'package:wanote/features/auth/data/account_document_eraser.dart';
import 'package:wanote/features/auth/data/account_file_eraser.dart';
import 'package:wanote/features/auth/data/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountFileEraser extends Mock implements AccountFileEraser {}

class MockAccountDocumentEraser extends Mock implements AccountDocumentEraser {}

class MockAccountBackendClient extends Mock implements AccountBackendClient {}

/// The ordering contract of account deletion.
///
/// These tests exist for one reason: deleting the Firebase Auth identity
/// before the data is gone is unrecoverable. firestore.rules, storage.rules
/// and every Worker route authorize on that identity, so the moment it is
/// deleted the remaining documents and files can never be reached again --
/// not by the user, not by a retry, not by support. It is the kind of
/// mistake that looks like a harmless reordering in review.
void main() {
  const uid = 'owner-uid';

  late MockAuthRepository authRepository;
  late MockAccountFileEraser fileEraser;
  late MockAccountDocumentEraser documentEraser;
  late MockAccountBackendClient backendClient;
  late List<String> calls;

  setUp(() {
    authRepository = MockAuthRepository();
    fileEraser = MockAccountFileEraser();
    documentEraser = MockAccountDocumentEraser();
    backendClient = MockAccountBackendClient();
    calls = [];

    when(() => fileEraser.erase(any())).thenAnswer((_) async {
      calls.add('files');
    });
    when(() => documentEraser.erase(any())).thenAnswer((_) async {
      calls.add('documents');
    });
    when(() => backendClient.deleteServerData()).thenAnswer((_) async {
      calls.add('server');
    });
    when(() => authRepository.deleteCurrentUser()).thenAnswer((_) async {
      calls.add('identity');
    });
  });

  DefaultAccountDeletionService buildService() => DefaultAccountDeletionService(
    authRepository: authRepository,
    fileEraser: fileEraser,
    documentEraser: documentEraser,
    backendClient: backendClient,
  );

  test('deletes the identity last, after every piece of data', () async {
    await buildService().deleteAccount(uid);

    expect(calls, ['files', 'documents', 'server', 'identity']);
  });

  test('erases files while the document tree still exists', () async {
    // The documents are the only index of what was ever uploaded. If a
    // deletion dies half way, having them still there is the difference
    // between auditable orphans and unattributable ones.
    await buildService().deleteAccount(uid);

    expect(calls.indexOf('files'), lessThan(calls.indexOf('documents')));
  });

  test('does not delete the identity when the file sweep fails', () async {
    when(() => fileEraser.erase(any())).thenThrow(Exception('storage down'));

    await expectLater(
      buildService().deleteAccount(uid),
      throwsA(isA<Exception>()),
    );

    verifyNever(() => authRepository.deleteCurrentUser());
  });

  test('does not delete the identity when the document sweep fails', () async {
    when(() => documentEraser.erase(any())).thenThrow(Exception('firestore'));

    await expectLater(
      buildService().deleteAccount(uid),
      throwsA(isA<Exception>()),
    );

    verifyNever(() => authRepository.deleteCurrentUser());
  });

  test('does not delete the identity when the backend sweep fails', () async {
    // The server-owned collections (rewards, pending grants, redemption
    // markers, the referral code) are unreachable without a valid ID token,
    // so giving up the identity here would strand them permanently.
    when(() => backendClient.deleteServerData()).thenThrow(
      AccountBackendException(statusCode: 502, message: 'backend down'),
    );

    await expectLater(
      buildService().deleteAccount(uid),
      throwsA(isA<AccountBackendException>()),
    );

    verifyNever(() => authRepository.deleteCurrentUser());
  });

  test('passes the uid through to both erasers', () async {
    await buildService().deleteAccount(uid);

    verify(() => fileEraser.erase(uid)).called(1);
    verify(() => documentEraser.erase(uid)).called(1);
  });
}
