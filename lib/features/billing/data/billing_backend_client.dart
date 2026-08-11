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

  /// Redeems [code] via `POST /billing/grant-promotional-entitlement`
  /// (functions/src/routes/grantPromotionalEntitlement.ts).
  ///
  /// The backend owns the whole decision: it looks the code up, checks it is
  /// active, within its cap, not the caller's own referral code and not
  /// already redeemed by them, and records the redemption -- all in one
  /// Firestore transaction -- before granting anything. This used to take no
  /// body at all and grant unconditionally, so any account could call it
  /// directly for free premium.
  ///
  /// Returns [BackendRedemptionResult.granted] true on success, or a
  /// machine-readable [BackendRedemptionResult.reason] the UI maps to a
  /// localized message. Throws [BillingBackendException] on a non-2xx
  /// response.
  Future<BackendRedemptionResult> grantPromotionalEntitlement(
    String code,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/billing/grant-promotional-entitlement'),
      headers: await _headers(),
      body: jsonEncode({'code': code}),
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
    return BackendRedemptionResult(
      granted: decoded['granted'] as bool? ?? false,
      reason: decoded['reason'] as String?,
    );
  }

  /// Calls `POST /billing/referral-code`, which returns the caller's own
  /// referral code and creates its `campaign_codes/{code}` document the
  /// first time.
  ///
  /// Also server-side now: `campaign_codes` is shared rather than owned, so
  /// clients are no longer allowed to write there at all.
  Future<String> fetchReferralCode() async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/billing/referral-code'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingBackendException(
        statusCode: response.statusCode,
        message: 'Could not load your referral code.',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['code'] as String;
  }
}

/// What the backend decided about a redemption. [reason] is one of
/// RedemptionIneligibleReason's names (see
/// functions/src/lib/campaignCodeEligibility.ts, which mirrors the Dart
/// enum) and is null when [granted] is true.
class BackendRedemptionResult {
  const BackendRedemptionResult({required this.granted, this.reason});

  final bool granted;
  final String? reason;
}

class BillingBackendException implements Exception {
  BillingBackendException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'BillingBackendException($statusCode): $message';
}
