import { describe, expect, it } from 'vitest';
import { parseOcrModelOutput } from '../src/lib/ocrParsing';

describe('parseOcrModelOutput', () => {
  it('parses a well-formed JSON response', () => {
    const raw = JSON.stringify({
      product_name: 'レプトスピラ混合ワクチン',
      administered_at: '2026-05-01',
      next_due_date: '2027-05-01',
      hospital_name: 'さくら動物病院',
      confidence: 0.92,
    });

    const result = parseOcrModelOutput(raw);

    expect(result).toEqual({
      extracted: {
        product_name: 'レプトスピラ混合ワクチン',
        administered_at: '2026-05-01',
        next_due_date: '2027-05-01',
        hospital_name: 'さくら動物病院',
      },
      confidence: 0.92,
    });
  });

  it('strips ```json fences some models add despite instructions', () => {
    const raw = '```json\n' + JSON.stringify({ product_name: 'X', confidence: 0.8 }) + '\n```';

    const result = parseOcrModelOutput(raw);

    expect(result.extracted.product_name).toBe('X');
    expect(result.confidence).toBe(0.8);
  });

  it('treats missing fields as null rather than throwing', () => {
    const raw = JSON.stringify({ confidence: 0.5 });

    const result = parseOcrModelOutput(raw);

    expect(result.extracted).toEqual({
      product_name: null,
      administered_at: null,
      next_due_date: null,
      hospital_name: null,
    });
    expect(result.confidence).toBe(0.5);
  });

  it('returns an all-null/no-confidence result for unparsable text', () => {
    const result = parseOcrModelOutput('not json at all');

    expect(result.confidence).toBeNull();
    expect(result.extracted.product_name).toBeNull();
  });

  it('returns an all-null result for empty text', () => {
    const result = parseOcrModelOutput('   ');

    expect(result.confidence).toBeNull();
  });

  it('normalizes an out-of-range confidence expressed as a percentage', () => {
    const raw = JSON.stringify({ confidence: 92 });

    const result = parseOcrModelOutput(raw);

    expect(result.confidence).toBe(0.92);
  });

  it('clamps a confidence above 1 after normalization to 1', () => {
    const raw = JSON.stringify({ confidence: 150 });

    const result = parseOcrModelOutput(raw);

    expect(result.confidence).toBe(1);
  });

  it('ignores non-string junk in text fields instead of throwing', () => {
    const raw = JSON.stringify({ product_name: 12345, confidence: 0.7 });

    const result = parseOcrModelOutput(raw);

    expect(result.extracted.product_name).toBeNull();
  });
});
