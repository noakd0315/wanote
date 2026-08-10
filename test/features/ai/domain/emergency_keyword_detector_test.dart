import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/ai/domain/emergency_keyword_detector.dart';

void main() {
  const detector = EmergencyKeywordDetector();

  group('default keyword list', () {
    for (final keyword in EmergencyKeywordDetector.defaultKeywords) {
      test('triggers for "$keyword"', () {
        expect(detector.isEmergency('うちの子が$keywordしています'), isTrue);
      });
    }
  });

  test('does not trigger for unrelated text', () {
    expect(detector.isEmergency('今日は元気にご飯を食べました'), isFalse);
  });

  test('does not trigger for empty or whitespace-only text', () {
    expect(detector.isEmergency(''), isFalse);
    expect(detector.isEmergency('   '), isFalse);
  });

  test('does not false-positive on near-miss text without a real keyword', () {
    // Contains characters that appear in "誤飲" and "けいれん" individually,
    // but never as the contiguous keyword substring.
    expect(detector.isEmergency('誤って飲み物をこぼした。けれど元気です。'), isFalse);
  });

  test('matches with internal ascii-whitespace variants', () {
    expect(detector.isEmergency('けい れん のような動きをしています'), isTrue);
  });

  test('matches with internal full-width space variants', () {
    expect(detector.isEmergency('意識　が　ない　ようです'), isTrue);
  });

  test('is case-insensitive for latin-letter keywords', () {
    const latinDetector = EmergencyKeywordDetector(keywords: ['SEIZURE']);
    expect(latinDetector.isEmergency('possible seizure observed'), isTrue);
    expect(latinDetector.isEmergency('possible SeIzUrE observed'), isTrue);
  });

  test(
    'supports a fully custom keyword list without the built-in defaults',
    () {
      const customDetector = EmergencyKeywordDetector(keywords: ['痙攣']);
      expect(customDetector.isEmergency('痙攣しています'), isTrue);
      expect(customDetector.isEmergency('けいれんしています'), isFalse);
    },
  );
}
