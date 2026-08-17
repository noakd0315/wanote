import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../shared/config/backend_config.dart';
import '../../../shared/models/consultation_reference_record.dart';
import '../models/monthly_report_input_stats.dart';

/// Thin HTTP client for the Cloudflare Workers backend defined under
/// functions/src/routes/{consultation,report}.ts. Callers pass a Firebase
/// ID token via [idTokenProvider] (defaults to the signed-in Firebase user)
/// so this class stays constructible/testable without wiring up
/// firebase_auth in a unit test.
class AiBackendClient {
  AiBackendClient({
    required this.baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? _defaultIdTokenProvider;

  /// Base URL of the deployed Cloudflare Worker, e.g.
  /// `https://wanote-functions.<subdomain>.workers.dev`. Configure via
  /// `--dart-define=AI_BACKEND_BASE_URL=...` at build time; see
  /// [AiBackendClient.fromEnvironment].
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _idTokenProvider;

  static Future<String?> _defaultIdTokenProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Reads the base URL from a `--dart-define=AI_BACKEND_BASE_URL=...`
  /// build-time constant. Without it, falls back to [fallbackBaseUrl] or --
  /// when that is null too -- to `wrangler dev` on whichever host served the
  /// page (see [defaultLocalBackendBaseUrl]; a phone on the LAN must not be
  /// sent to its own localhost).
  factory AiBackendClient.fromEnvironment({
    String? fallbackBaseUrl,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  }) {
    const configured = configuredBackendBaseUrl;
    return AiBackendClient(
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

  /// Calls `POST /ai/consultation` (functions/src/routes/consultation.ts).
  /// Throws [AiBackendException] on any non-2xx response.
  /// [languageCode] is the language the *answer* should come back in --
  /// normally `Localizations.localeOf(context).languageCode`. The backend
  /// falls back to Japanese for anything it doesn't recognize, so passing
  /// nothing keeps the previous behaviour.
  Future<String> requestConsultation({
    required String petId,
    required String questionText,
    List<ConsultationReferenceRecord> referencedRecords = const [],
    String? languageCode,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/ai/consultation'),
      headers: await _headers(),
      body: jsonEncode({
        'petId': petId,
        'questionText': questionText,
        'language': ?languageCode,
        'referencedRecords': referencedRecords
            .map(
              (r) => {
                'recordId': r.recordId,
                'recordType': r.recordType.wireName,
                'label': r.label,
                'tags': r.tags,
              },
            )
            .toList(),
      }),
    );
    return _extractResponseText(response);
  }

  /// Calls `POST /ai/report` (functions/src/routes/report.ts).
  Future<String> requestMonthlyReport({
    required String petId,
    required MonthlyReportInputStats stats,
    String? languageCode,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/ai/report'),
      headers: await _headers(),
      body: jsonEncode({
        'petId': petId,
        'language': ?languageCode,
        'periodStart': _dateOnly(stats.periodStart),
        'periodEnd': _dateOnly(stats.periodEnd),
        'weightSamples': stats.weightSamples
            .map((s) => {'date': _dateOnly(s.date), 'weightKg': s.weightKg})
            .toList(),
        'toiletCountsByDay': stats.toiletCountsByDay
            .map((c) => {'date': _dateOnly(c.date), 'count': c.count})
            .toList(),
      }),
    );
    return _extractResponseText(response);
  }

  /// Decodes the body as UTF-8, rather than however the headers ask.
  ///
  /// `response.body` picks its codec from the Content-Type charset, and
  /// falls back to **latin-1** when there isn't one. The Worker sent
  /// `application/json` with no charset, so a Japanese answer came back
  /// with characters replaced by U+FFFD -- the PM saw 栄 render as a black
  /// diamond in the middle of 栄養管理 (2026-08-17).
  ///
  /// The Worker now sends the charset too, but this does not depend on it.
  /// JSON is UTF-8 by definition (RFC 8259), so reading the bytes that way
  /// is right whatever the header says, and it cannot regress the next time
  /// a route is added without one.
  String _decodeBody(http.Response response) =>
      utf8.decode(response.bodyBytes, allowMalformed: true);

  String _extractResponseText(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        final decoded = jsonDecode(_decodeBody(response)) as Map<String, dynamic>;
        message = decoded['error'] as String?;
      } catch (_) {
        // Body wasn't JSON; fall back to the generic message below.
      }
      throw AiBackendException(
        statusCode: response.statusCode,
        message:
            message ?? 'AI backend request failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(_decodeBody(response)) as Map<String, dynamic>;
    return decoded['responseText'] as String;
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class AiBackendException implements Exception {
  AiBackendException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'AiBackendException($statusCode): $message';
}
