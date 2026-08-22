/**
 * Output-language directive appended to the AI system prompts.
 *
 * The prompts themselves are written in English and there is only one copy
 * of them, which is the point: the earlier arrangement kept them in Japanese
 * precisely to avoid maintaining two translations of the safety rules that
 * could drift apart. One canonical copy answers that concern outright, and
 * puts every future edit in a single place.
 *
 * The owner's own words are never translated on the way in. A description of
 * a symptom loses too much in translation, and a mistranslated symptom is a
 * worse failure than a prompt and a question being in different languages --
 * which the model handles without difficulty.
 *
 * The reply is written directly in the target language rather than drafted
 * in one and translated, which reads more naturally and costs one pass
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
      '- Write your answer in English. Write it as English from the start,',
      '  not as a translation of something drafted in another language.',
      '- Answer in English even when the question is written in another',
      '  language, and even when it is gibberish or makes no sense. The',
      '  language is set by the owner, not by the question.',
      '- Aim for roughly 150-250 words.',
    ].join('\n');
  }
  return [
    '- Write your answer in Japanese (日本語). Write it as Japanese from the',
    '  start, not as a translation of something drafted in English.',
    '- 質問が他の言語で書かれていても、意味をなさない文字列であっても、',
    '  日本語で答えること。言語は飼い主の設定で決まるのであって、質問の',
    '  見た目で決まるのではない。',
    '- Aim for roughly 200-400 characters.',
  ].join('\n');
}
