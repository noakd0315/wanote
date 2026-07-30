/**
 * Pure JSON-parsing/validation logic for the AI-OCR certificate route (spec
 * 5.4). Split out from routes/ocr.ts so it can be unit-tested without any
 * network/fetch/Anthropic call -- this is the part the task asks to cover
 * with vitest.
 */

export interface OcrExtractedFields {
  product_name: string | null;
  administered_at: string | null;
  next_due_date: string | null;
  hospital_name: string | null;
}

export interface ParsedOcrResult {
  extracted: OcrExtractedFields;
  confidence: number | null;
}

/**
 * System prompt sent to Claude Haiku 4.5 (vision). Kept as a single string
 * constant so callClaude() can cache_control it (spec section 9 cost note).
 */
export const OCR_SYSTEM_PROMPT = `You are extracting structured data from a photo of a dog's veterinary certificate (vaccine certificate, heartworm test result, or flea/tick prevention certificate).

Return ONLY a single JSON object (no markdown fences, no prose) with exactly this shape:
{
  "product_name": string | null,
  "administered_at": string | null,   // ISO 8601 date (YYYY-MM-DD) the treatment/vaccine was administered
  "next_due_date": string | null,     // ISO 8601 date (YYYY-MM-DD) of the next recommended dose, if printed on the certificate
  "hospital_name": string | null,     // the issuing veterinary hospital/clinic name
  "confidence": number               // your confidence in this extraction, from 0.0 (illegible/guessing) to 1.0 (certain)
}

Rules:
- If a field is not present or not legible on the certificate, use null for that field (do not guess).
- Dates must be normalized to YYYY-MM-DD. If only a year and month are legible, use the first of the month.
- "confidence" must reflect the OVERALL extraction quality (handwriting, image blur, and printed vs. handwritten fields should all lower it).
- Output must be valid JSON and nothing else.`;

function safeString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function safeConfidence(value: unknown): number | null {
  if (typeof value !== 'number' || Number.isNaN(value)) return null;
  // Clamp defensively -- a model could return e.g. 95 meaning 95%.
  const normalized = value > 1 ? value / 100 : value;
  return Math.min(1, Math.max(0, normalized));
}

/**
 * Parses the raw text Claude returned (expected to be a single JSON object,
 * per [OCR_SYSTEM_PROMPT]) into the shape the client expects. Never throws:
 * malformed/non-JSON output degrades to "everything null, confidence null",
 * which [OcrResultValidator] on the client treats as a fallback-to-manual
 * case rather than a crash.
 */
export function parseOcrModelOutput(rawText: string): ParsedOcrResult {
  const emptyResult: ParsedOcrResult = {
    extracted: {
      product_name: null,
      administered_at: null,
      next_due_date: null,
      hospital_name: null,
    },
    confidence: null,
  };

  const trimmed = rawText.trim();
  if (!trimmed) return emptyResult;

  // Models occasionally wrap JSON in ```json fences despite instructions;
  // strip those defensively before parsing.
  const withoutFences = trimmed
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/, '')
    .trim();

  let parsed: unknown;
  try {
    parsed = JSON.parse(withoutFences);
  } catch {
    return emptyResult;
  }

  if (typeof parsed !== 'object' || parsed === null) {
    return emptyResult;
  }
  const obj = parsed as Record<string, unknown>;

  return {
    extracted: {
      product_name: safeString(obj.product_name),
      administered_at: safeString(obj.administered_at),
      next_due_date: safeString(obj.next_due_date),
      hospital_name: safeString(obj.hospital_name),
    },
    confidence: safeConfidence(obj.confidence),
  };
}
