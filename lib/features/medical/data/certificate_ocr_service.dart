import 'dart:convert';

import 'package:http/http.dart' as http;

/// Parsed response from the `/ocr/certificate` Cloudflare Worker route
/// (functions/src/routes/ocr.ts). Field names mirror
/// `prevention_records.ocr_extracted_data`'s contents (spec 5.4) so the
/// review screen can copy them straight into form fields.
class OcrExtractionResult {
  const OcrExtractionResult({
    required this.extractedData,
    required this.confidence,
    this.productName,
    this.administeredAt,
    this.nextDueDate,
    this.hospitalName,
  });

  /// The full, raw extraction payload as returned by the backend — stored
  /// verbatim as `ocr_extracted_data` regardless of confidence (spec 5.4
  /// step 5: "元画像／PDFは certificate_file として、抽出結果は
  /// ocr_extracted_data として保存").
  final Map<String, dynamic> extractedData;

  /// `ocr_confidence`. `null` if the backend couldn't produce one (treated
  /// as "low confidence" by [OcrResultValidator]).
  final double? confidence;

  final String? productName;
  final DateTime? administeredAt;
  final DateTime? nextDueDate;
  final String? hospitalName;

  factory OcrExtractionResult.fromJson(Map<String, dynamic> json) {
    final extracted = (json['extracted'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OcrExtractionResult(
      extractedData: extracted,
      confidence: (json['confidence'] as num?)?.toDouble(),
      productName: extracted['product_name'] as String?,
      administeredAt: _tryParseDate(extracted['administered_at']),
      nextDueDate: _tryParseDate(extracted['next_due_date']),
      hospitalName: extracted['hospital_name'] as String?,
    );
  }

  static DateTime? _tryParseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class CertificateOcrException implements Exception {
  CertificateOcrException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'CertificateOcrException($statusCode): $message';
}

/// Client for the AI-OCR backend (spec 5.4). Kept behind an interface so the
/// capture/review screen can be tested with a fake instead of making real
/// HTTP calls.
abstract class CertificateOcrService {
  /// [base64Image] must already be resized/compressed client-side (spec
  /// 5.4 step 2 — done via flutter_image_compress before this is called).
  /// [idToken] is the current user's Firebase ID token, sent as
  /// `Authorization: Bearer <idToken>` so the Worker can verify identity via
  /// verifyFirebaseToken().
  Future<OcrExtractionResult> extractCertificateData({
    required String base64Image,
    required String mediaType,
    required String idToken,
  });
}

class HttpCertificateOcrService implements CertificateOcrService {
  HttpCertificateOcrService({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Base URL of the deployed Cloudflare Worker, e.g.
  /// `https://wanote-functions.<account>.workers.dev`.
  final String baseUrl;
  final http.Client _httpClient;

  @override
  Future<OcrExtractionResult> extractCertificateData({
    required String base64Image,
    required String mediaType,
    required String idToken,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/ocr/certificate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'image_base64': base64Image, 'media_type': mediaType}),
    );

    if (response.statusCode == 429) {
      throw CertificateOcrException(
        'Rate limit exceeded, try again later.',
        statusCode: 429,
      );
    }
    if (response.statusCode != 200) {
      throw CertificateOcrException(
        'OCR request failed: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return OcrExtractionResult.fromJson(json);
  }
}
