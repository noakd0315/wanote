import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/auth/data/account_file_eraser.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

class MockListResult extends Mock implements ListResult {}

class FakeListOptions extends Fake implements ListOptions {}

/// Account deletion's Storage sweep.
///
/// Storage has no recursive delete and `list` is paginated, so the walk is
/// hand-rolled -- two places a bug hides without any error surfacing. A
/// missed page or an unvisited subfolder just means the user's vaccination
/// certificates quietly stay in the bucket after they asked for everything
/// to be gone.
void main() {
  setUpAll(() {
    registerFallbackValue(FakeListOptions());
  });

  const uid = 'owner-uid';

  late MockFirebaseStorage storage;
  late Map<String, MockReference> refs;
  late List<String> deleted;

  MockReference file(String path) {
    final ref = refs.putIfAbsent(path, MockReference.new);
    when(ref.delete).thenAnswer((_) async {
      deleted.add(path);
    });
    return ref;
  }

  /// Builds a reference at [path] whose `list` returns [pages] in order.
  /// Each page is (files, subfolders, hasMore).
  MockReference folder(
    String path,
    List<(List<String>, List<String>, bool)> pages,
  ) {
    final ref = refs.putIfAbsent(path, MockReference.new);
    // Built up front, not inside thenAnswer: mocktail forbids stubbing from
    // within a stub response.
    final results = <MockListResult>[];
    for (var i = 0; i < pages.length; i++) {
      final (files, subfolders, hasMore) = pages[i];
      final result = MockListResult();
      // file() stubs as a side effect, so it has to run before when() opens
      // its own stubbing state -- not inside the thenReturn argument.
      final items = files
          .map<Reference>((name) => file('$path/$name'))
          .toList();
      final prefixes = subfolders
          .map<Reference>((name) => refs['$path/$name']!)
          .toList();
      when(() => result.items).thenReturn(items);
      when(() => result.prefixes).thenReturn(prefixes);
      when(() => result.nextPageToken).thenReturn(hasMore ? 'token-$i' : null);
      results.add(result);
    }
    var call = 0;
    when(() => ref.list(any())).thenAnswer((_) async => results[call++]);
    return ref;
  }

  setUp(() {
    storage = MockFirebaseStorage();
    refs = {};
    deleted = [];
  });

  StorageAccountFileEraser buildEraser() =>
      StorageAccountFileEraser(storage: storage);

  test('deletes files nested several folders deep', () async {
    // The real shape: users/{uid}/pets/{petId}/health_records/{recordId}/0.jpg
    // is four levels below the account root.
    folder('users/$uid/pets/pet-1/health_records/r1', [
      (['0.jpg', '1.jpg'], [], false),
    ]);
    folder('users/$uid/pets/pet-1/health_records', [
      ([], ['r1'], false),
    ]);
    folder('users/$uid/pets/pet-1', [
      (['profile.jpg'], ['health_records'], false),
    ]);
    folder('users/$uid/pets', [
      ([], ['pet-1'], false),
    ]);
    final root = folder('users/$uid', [
      ([], ['pets'], false),
    ]);
    when(() => storage.ref('users/$uid')).thenReturn(root);

    await buildEraser().erase(uid);

    expect(deleted, [
      'users/$uid/pets/pet-1/profile.jpg',
      'users/$uid/pets/pet-1/health_records/r1/0.jpg',
      'users/$uid/pets/pet-1/health_records/r1/1.jpg',
    ]);
  });

  test(
    'follows the page token instead of stopping at the first page',
    () async {
      // A pet with a long history has more objects in one folder than a single
      // list() returns. Ignoring nextPageToken leaves everything after the
      // first hundred behind, and nothing reports an error.
      final root = folder('users/$uid', [
        (['a.jpg'], [], true),
        (['b.jpg'], [], true),
        (['c.jpg'], [], false),
      ]);
      when(() => storage.ref('users/$uid')).thenReturn(root);

      await buildEraser().erase(uid);

      expect(deleted, [
        'users/$uid/a.jpg',
        'users/$uid/b.jpg',
        'users/$uid/c.jpg',
      ]);
    },
  );

  test('visits subfolders found on a later page too', () async {
    folder('users/$uid/pets', [
      (['icon.jpg'], [], false),
    ]);
    final root = folder('users/$uid', [
      ([], [], true),
      ([], ['pets'], false),
    ]);
    when(() => storage.ref('users/$uid')).thenReturn(root);

    await buildEraser().erase(uid);

    expect(deleted, ['users/$uid/pets/icon.jpg']);
  });

  test('starts from the account root, not the bucket root', () async {
    // Everything the app uploads lives under users/{uid}, and nothing above
    // it belongs to this account.
    final root = folder('users/$uid', [([], [], false)]);
    when(() => storage.ref('users/$uid')).thenReturn(root);

    await buildEraser().erase(uid);

    verify(() => storage.ref('users/$uid')).called(1);
  });

  test('succeeds on an account that never uploaded anything', () async {
    final root = folder('users/$uid', [([], [], false)]);
    when(() => storage.ref('users/$uid')).thenReturn(root);

    await expectLater(buildEraser().erase(uid), completes);
    expect(deleted, isEmpty);
  });
}
