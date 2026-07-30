/// What the certificate-review screen should do with an AI-OCR result.
enum OcrValidationOutcome {
  /// Confidence met the threshold: prefill the form fields from
  /// `ocr_extracted_data`, but the user must still confirm/edit before
  /// saving (spec 5.4 step 4 — never auto-save).
  prefillForReview,

  /// Confidence missing or below threshold: show
  /// "読み取れませんでした。手動で入力してください" and leave the form blank.
  fallbackManualEntry,
}

/// Pure decision of prefill-vs-fallback from an OCR confidence score (spec
/// 5.4's "ocr_confidence が閾値未満の場合はフォールバック" rule). No network/
/// Claude API call lives here — this only judges the number the backend
/// already returned.
class OcrResultValidator {
  const OcrResultValidator({this.threshold = defaultConfidenceThreshold});

  /// 0.6 is a reasonable starting default for a vision-model confidence
  /// score on a photographed certificate: low enough to still prefill most
  /// legibly-photographed certificates (reducing manual typing, the whole
  /// point of 5.4), high enough to route obviously-bad reads (blurry photos,
  /// handwritten certs the spec calls out explicitly) to manual entry rather
  /// than risk silently-wrong medical data. Should be tuned once real
  /// extraction accuracy is measured (spec section 11, open item 8).
  static const double defaultConfidenceThreshold = 0.6;

  final double threshold;

  /// [confidence] is `null` when the backend couldn't produce a confidence
  /// estimate at all (e.g. malformed model output) — treated the same as
  /// "too low", per spec's anti-misread requirement: absence of a trustworthy
  /// score is not grounds for prefilling.
  OcrValidationOutcome evaluate(double? confidence) {
    if (confidence == null) {
      return OcrValidationOutcome.fallbackManualEntry;
    }
    // >= threshold prefills; exactly-at-threshold counts as "meets the bar".
    return confidence >= threshold
        ? OcrValidationOutcome.prefillForReview
        : OcrValidationOutcome.fallbackManualEntry;
  }
}
