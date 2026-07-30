import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/domain/ocr_result_validator.dart';

void main() {
  group('OcrResultValidator', () {
    test('confidence above threshold prefills the form', () {
      const validator = OcrResultValidator(threshold: 0.6);

      expect(
        validator.evaluate(0.9),
        OcrValidationOutcome.prefillForReview,
      );
    });

    test('confidence below threshold falls back to manual entry', () {
      const validator = OcrResultValidator(threshold: 0.6);

      expect(
        validator.evaluate(0.3),
        OcrValidationOutcome.fallbackManualEntry,
      );
    });

    test('confidence exactly at threshold prefills the form', () {
      const validator = OcrResultValidator(threshold: 0.6);

      expect(
        validator.evaluate(0.6),
        OcrValidationOutcome.prefillForReview,
      );
    });

    test('missing confidence falls back to manual entry', () {
      const validator = OcrResultValidator(threshold: 0.6);

      expect(
        validator.evaluate(null),
        OcrValidationOutcome.fallbackManualEntry,
      );
    });

    test('uses the documented default threshold of 0.6', () {
      const validator = OcrResultValidator();

      expect(validator.evaluate(0.59), OcrValidationOutcome.fallbackManualEntry);
      expect(validator.evaluate(0.6), OcrValidationOutcome.prefillForReview);
    });
  });
}
