import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wanote/features/auth/data/account_backend_client.dart';

/// The client half of the server-side sweep.
///
/// Small surface, but two details matter: the ID token has to be attached
/// (the route authorizes off it and returns 401 without one), and a non-2xx
/// has to throw rather than be swallowed -- silently continuing would let
/// the caller delete the Firebase Auth identity while the server-owned
/// collections were still there, which is unrecoverable.
void main() {
  const baseUrl = 'https://api.example.test';

  AccountBackendClient buildClient(
    Future<http.Response> Function(http.Request) handler, {
    String? token = 'id-token',
  }) {
    return AccountBackendClient(
      baseUrl: baseUrl,
      httpClient: MockClient(handler),
      idTokenProvider: () async => token,
    );
  }

  test('posts to the account deletion route with the ID token', () async {
    late http.Request captured;
    final client = buildClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'deleted': 3}), 200);
    });

    await client.deleteServerData();

    expect(captured.method, 'POST');
    expect(captured.url.toString(), '$baseUrl/account/delete-server-data');
    expect(captured.headers['authorization'], 'Bearer id-token');
  });

  test('sends no body -- the uid comes from the token', () async {
    // Deliberate: a body naming the account to delete would be a caller
    // choosing whose data disappears.
    late http.Request captured;
    final client = buildClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'deleted': 0}), 200);
    });

    await client.deleteServerData();

    expect(captured.body, isEmpty);
  });

  test('throws on a failure response', () async {
    final client = buildClient(
      (_) async => http.Response(
        jsonEncode({'error': 'Could not delete your account data.'}),
        502,
      ),
    );

    await expectLater(
      client.deleteServerData(),
      throwsA(
        isA<AccountBackendException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having(
              (e) => e.message,
              'message',
              'Could not delete your account data.',
            ),
      ),
    );
  });

  test('throws on a failure whose body is not JSON', () async {
    // Cloudflare's own error pages are HTML, not JSON.
    final client = buildClient((_) async => http.Response('<html>', 500));

    await expectLater(
      client.deleteServerData(),
      throwsA(isA<AccountBackendException>()),
    );
  });

  test('still sends the request when there is no token', () async {
    // The route answers 401, which surfaces as a thrown exception rather
    // than a silent success.
    late http.Request captured;
    final client = buildClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'error': 'Unauthorized.'}), 401);
    }, token: null);

    await expectLater(
      client.deleteServerData(),
      throwsA(isA<AccountBackendException>()),
    );
    expect(captured.headers.containsKey('authorization'), isFalse);
  });
}
