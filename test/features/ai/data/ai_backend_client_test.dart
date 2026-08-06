import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wanote/features/ai/data/ai_backend_client.dart';
import 'package:wanote/features/ai/models/monthly_report_input_stats.dart';

/// Covers the wire contract with functions/src/routes/{consultation,report}.ts.
/// The answer's language is decided server-side from this `language` field, so
/// silently dropping it would send an English user Japanese text with no error
/// anywhere -- exactly the kind of failure a type-checker can't catch.
void main() {
  late List<Map<String, dynamic>> sentBodies;

  AiBackendClient buildClient() {
    sentBodies = [];
    final mock = MockClient((request) async {
      sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'responseText': 'ok'}), 200);
    });
    return AiBackendClient(
      baseUrl: 'https://example.test',
      httpClient: mock,
      idTokenProvider: () async => 'token',
    );
  }

  final stats = MonthlyReportInputStats(
    periodStart: DateTime(2026, 7, 1),
    periodEnd: DateTime(2026, 7, 31),
    weightSamples: const [],
    toiletCountsByDay: const [],
  );

  group('requestConsultation', () {
    test('sends the requested answer language', () async {
      final client = buildClient();
      await client.requestConsultation(
        petId: 'pet-1',
        questionText: 'q',
        languageCode: 'en',
      );
      expect(sentBodies.single['language'], 'en');
    });

    test('omits language entirely when none is given', () async {
      final client = buildClient();
      await client.requestConsultation(petId: 'pet-1', questionText: 'q');
      expect(sentBodies.single.containsKey('language'), isFalse);
    });
  });

  group('requestMonthlyReport', () {
    test('sends the requested answer language', () async {
      final client = buildClient();
      await client.requestMonthlyReport(
        petId: 'pet-1',
        stats: stats,
        languageCode: 'en',
      );
      expect(sentBodies.single['language'], 'en');
    });

    test('omits language entirely when none is given', () async {
      final client = buildClient();
      await client.requestMonthlyReport(petId: 'pet-1', stats: stats);
      expect(sentBodies.single.containsKey('language'), isFalse);
    });
  });
}
