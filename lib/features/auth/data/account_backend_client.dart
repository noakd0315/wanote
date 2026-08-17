import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../shared/config/backend_config.dart';

/// Thin HTTP client for the account routes on the Cloudflare Workers backend
/// (functions/src/routes/deleteAccountServerData.ts).
///
/// Same `--dart-define=AI_BACKEND_BASE_URL` convention and same deployed
/// Worker as AiBackendClient / BillingBackendClient, kept as its own class so
/// features/auth doesn't reach into another feature's directory
/// (wanote/.claude/CLAUDE.md).
class AccountBackendClient {
  AccountBackendClient({
    required this.baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? _defaultIdTokenProvider;

  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _idTokenProvider;

  static Future<String?> _defaultIdTokenProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  factory AccountBackendClient.fromEnvironment({
    String? fallbackBaseUrl,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  }) {
    const configured = configuredBackendBaseUrl;
    return AccountBackendClient(
      baseUrl: configured.isEmpty
          ? (fallbackBaseUrl ?? defaultLocalBackendBaseUrl())
          : configured,
      httpClient: httpClient,
      idTokenProvider: idTokenProvider,
    );
  }

  /// Calls `POST /account/delete-server-data`, which erases the parts of the
  /// account only the backend may touch: the referral counter
  /// (`users/{uid}/rewards`), undelivered rewards
  /// (`users/{uid}/pending_grants`), redemption markers
  /// (`users/{uid}/redeemed_codes`) and the user's own
  /// `campaign_codes/{code}` document.
  ///
  /// firestore.rules denies clients even a *read* of those, deliberately --
  /// a client that can delete its own redemption marker can redeem the same
  /// code twice. So they cannot be part of the client-side sweep, and an
  /// account deletion that skipped this call would leave the user's uid
  /// behind in four places.
  ///
  /// Throws [AccountBackendException] on a non-2xx response.
  Future<void> deleteServerData() async {
    final token = await _idTokenProvider();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/account/delete-server-data'),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        message =
            (jsonDecode(_decodeBody(response)) as Map<String, dynamic>)['error']
                as String?;
      } catch (_) {
        // Body wasn't JSON; fall back to the generic message below.
      }
      throw AccountBackendException(
        statusCode: response.statusCode,
        message:
            message ??
            'Account backend request failed (${response.statusCode}).',
      );
    }
  }
}

class AccountBackendException implements Exception {
  AccountBackendException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'AccountBackendException($statusCode): $message';

}

/// JSON is UTF-8 by definition (RFC 8259). `response.body` instead picks its
/// codec from the Content-Type charset and falls back to latin-1 when there
/// is none, which turned Japanese into U+FFFD in the AI answers (PM report,
/// 2026-08-17). Reading the bytes directly does not depend on a header being
/// right.
String _decodeBody(http.Response response) =>
    utf8.decode(response.bodyBytes, allowMalformed: true);
