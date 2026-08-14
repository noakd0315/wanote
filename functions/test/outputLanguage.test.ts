import { describe, expect, it } from 'vitest';
import {
  outputLanguageInstruction,
  parseOutputLanguage,
} from '../src/lib/outputLanguage';

describe('parseOutputLanguage', () => {
  it('accepts en, and falls back to ja for anything else', () => {
    expect(parseOutputLanguage('en')).toBe('en');
    expect(parseOutputLanguage('ja')).toBe('ja');
    // Unknown/absent must not break an older client.
    expect(parseOutputLanguage(undefined)).toBe('ja');
    expect(parseOutputLanguage('fr')).toBe('ja');
    expect(parseOutputLanguage(42)).toBe('ja');
  });
});

describe('outputLanguageInstruction', () => {
  it('asks for Japanese with a character-count target', () => {
    const ja = outputLanguageInstruction('ja');
    expect(ja).toContain('日本語');
    expect(ja).toContain('200-400 characters');
  });

  it('asks for natively-written English with a word-count target', () => {
    const en = outputLanguageInstruction('en');
    expect(en).toContain('in English');
    // Length is expressed in words, not characters: 200-400 English
    // characters would be a fraction of the Japanese answer's substance.
    expect(en).toContain('150-250 words');
    expect(en).not.toContain('200-400 characters');
    // The reply must be written in English directly, not translated.
    expect(en).toContain('English from the start');
  });
});

describe('the directive actually reaches the composed system prompts', () => {
  it('consultation switches its output-language line', async () => {
    const { buildSystemPrompt } = await import('../src/routes/consultation');
    expect(buildSystemPrompt('ja')).toContain('in Japanese');
    expect(buildSystemPrompt('en')).toContain('in English');
    // Safety framing must survive unchanged in both languages.
    for (const lang of ['ja', 'en'] as const) {
      expect(buildSystemPrompt(lang)).toContain('You are not a veterinarian');
      expect(buildSystemPrompt(lang)).toContain('three levels');
    }
  });

  it('report switches its output-language line', async () => {
    const { buildSystemPrompt } = await import('../src/routes/report');
    expect(buildSystemPrompt('ja')).toContain('in Japanese');
    expect(buildSystemPrompt('en')).toContain('in English');
    for (const lang of ['ja', 'en'] as const) {
      expect(buildSystemPrompt(lang)).toContain('Do not speculate about diagnoses');
    }
  });
});
