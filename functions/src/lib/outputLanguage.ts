/**
 * Output-language directive appended to the AI system prompts.
 *
 * The prompts themselves stay in Japanese even when the reply is English:
 * they carry the reviewed safety framing (受診目安の3段階, 診断しない, etc.),
 * and maintaining a second translated copy of those rules would let the two
 * drift apart -- a mistranslated safety rule is a much worse failure than a
 * Japanese instruction producing an English answer, which Claude handles
 * fine. So only the *output* language is parameterized here.
 *
 * The reply is written directly in the target language rather than drafted
 * in Japanese and translated, which reads more naturally and costs one pass
 * instead of two.
 */
export type OutputLanguage = 'ja' | 'en';

/** Falls back to Japanese for anything unrecognized (including absent),
 * so an older client that sends no locale keeps its current behaviour. */
export function parseOutputLanguage(raw: unknown): OutputLanguage {
  return raw === 'en' ? 'en' : 'ja';
}

/**
 * Length is specified per language because the units aren't comparable:
 * 200-400 Japanese characters is a short paragraph, while 200-400 English
 * characters is barely two sentences. Word counts keep the English answer
 * the same *substance* as the Japanese one rather than the same byte count.
 */
export function outputLanguageInstruction(language: OutputLanguage): string {
  if (language === 'en') {
    return [
      '- 出力は英語で書いてください。日本語で書いてから訳すのではなく、',
      '  最初から英語ネイティブが読んで自然な文章として書いてください。',
      '- 長さは150〜250語程度を目安に簡潔にまとめてください。',
    ].join('\n');
  }
  return '- 出力は日本語、200〜400文字程度を目安に簡潔にまとめてください。';
}
