import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/config/backend_config.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP client for the billing-related routes on the Cloudflare
/// Workers backend (functions/src/routes/grantPromotionalEntitlement.ts).
///
/// This is a small, billing-owned twin of
/// lib/features/ai/data/ai_backend_client.dart's AiBackendClient -- same
/// `--dart-define=AI_BACKEND_BASE_URL` convention, same deployed Worker,
/// just a different route -- kept as its own class rather than reusing
/// AiBackendClient so this feature doesn't reach into features/ai's
/// directory (wanote/.claude/CLAUDE.md: each feature only touches its own
/// directory).
class BillingBackendClient {
  BillingBackendClient({
    required this.baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? _defaultIdTokenProvider;

  /// Base URL of the deployed Cloudflare Worker. Configure via
  /// `--dart-define=AI_BACKEND_BASE_URL=...` at build time; see
  /// [BillingBackendClient.fromEnvironment].
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _idTokenProvider;

  static Future<String?> _defaultIdTokenProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Reads the base URL from the same `--dart-define=AI_BACKEND_BASE_URL`
  /// build-time constant AiBackendClient uses (it's the same Worker),
  /// falling back to [fallbackBaseUrl], or to local `wrangler dev` on the
  /// host that served the page (see [defaultLocalBackendBaseUrl]).
  factory BillingBackendClient.fromEnvironment({
    String? fallbackBaseUrl,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  }) {
    const configured = configuredBackendBaseUrl;
    return BillingBackendClient(
      baseUrl: configured.isEmpty
          ? (fallbackBaseUrl ?? defaultLocalBackendBaseUrl())
          : configured,
      httpClient: httpClient,
      idTokenProvider: idTokenProvider,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await _idTokenProvider();
    return {
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  /// Calls `POST /billing/grant-promotional-entitlement`
  /// (functions/src/routes/grantPromotionalEntitlement.ts). No request body
  /// is needed -- the backend derives the uid from the Firebase ID token
  /// and both the entitlement and the reward duration are fixed
  /// server-side. Returns true iff the backend reports the entitlement was
  /// granted. Throws [BillingBackendException] on a non-2xx response.
  Future<bool> grantPromotionalEntitlement() async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/billing/grant-promotional-entitlement'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        message = decoded['error'] as String?;
      } catch (_) {
        // Body wasn't JSON; fall back to the generic message below.
      }
      throw BillingBackendException(
        statusCode: response.statusCode,
        message:
            message ??
            'Billing backend request failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['granted'] as bool? ?? false;
  }
}

class BillingBackendException implements Exception {
  BillingBackendException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'BillingBackendException($statusCode): $message';
}
