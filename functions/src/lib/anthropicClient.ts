import type { Env } from './env';

const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';
export const CLAUDE_HAIKU_MODEL = 'claude-haiku-4-5';

export interface AnthropicImageInput {
  mediaType: 'image/jpeg' | 'image/png' | 'image/webp';
  base64Data: string;
}

interface CallClaudeParams {
  env: Env;
  /** Static safety/role instructions. Sent with cache_control so repeated
   * calls reuse the cached prefix instead of re-billing full input tokens
   * every time (spec section 9's cost-reduction note). */
  systemPrompt: string;
  userText: string;
  image?: AnthropicImageInput;
  maxTokens?: number;
}

export interface ClaudeResult {
  text: string;
  stopReason: string | null;
}

const MOCK_RESPONSE_PREFIX = '[MOCK RESPONSE — set ANTHROPIC_API_KEY for a real answer]';

/** Deterministic, unmistakably-fake stand-in for a real Claude response, used
 * by callClaude() below when no ANTHROPIC_API_KEY is configured. This lets
 * the full OCR / AI-consultation / AI-report click-through flow be demoed at
 * zero API cost and without an Anthropic account — see docs/local_dev.md.
 * The prefix/suffix are deliberately loud so this can never be mistaken for
 * a genuine model answer. */
function buildMockClaudeResult({
  systemPrompt,
  userText,
  image,
}: Pick<CallClaudeParams, 'systemPrompt' | 'userText' | 'image'>): ClaudeResult {
  const imageNote = image
    ? ' An image was attached but is not analyzed in mock mode.'
    : '';
  const promptPreview = userText.length > 280 ? `${userText.slice(0, 280)}…` : userText;
  return {
    text:
      `${MOCK_RESPONSE_PREFIX} This is a canned local-dev placeholder, not a real ` +
      `Claude response.${imageNote} It was generated from this request (system ` +
      `prompt: "${systemPrompt.slice(0, 60)}…"):\n\n${promptPreview}\n\n` +
      `${MOCK_RESPONSE_PREFIX}`,
    stopReason: 'mock',
  };
}

/** Thin wrapper around the Messages API. Every feature-specific route
 * (ocr.ts, consultation.ts, report.ts) builds its own system prompt and
 * calls this — the API key never leaves this Worker.
 *
 * Local-dev fallback: if env.ANTHROPIC_API_KEY is empty/unset (e.g. the PM
 * hasn't filled in functions/.dev.vars, see functions/.dev.vars.example),
 * this returns a clearly-labeled mock response instead of calling the real
 * API or throwing, so every AI-backed flow stays click-through-able for
 * free. Signature/return shape is unchanged either way. */
export async function callClaude({
  env,
  systemPrompt,
  userText,
  image,
  maxTokens = 1024,
}: CallClaudeParams): Promise<ClaudeResult> {
  if (!env.ANTHROPIC_API_KEY || env.ANTHROPIC_API_KEY.trim().length === 0) {
    console.warn(
      '[anthropicClient] ANTHROPIC_API_KEY is not set — returning a mock response instead of ' +
        'calling the real Anthropic API. See functions/.dev.vars.example to configure a real key.',
    );
    return buildMockClaudeResult({ systemPrompt, userText, image });
  }

  const content: Record<string, unknown>[] = [];
  if (image) {
    content.push({
      type: 'image',
      source: {
        type: 'base64',
        media_type: image.mediaType,
        data: image.base64Data,
      },
    });
  }
  content.push({ type: 'text', text: userText });

  const response = await fetch(ANTHROPIC_API_URL, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': ANTHROPIC_VERSION,
    },
    body: JSON.stringify({
      model: CLAUDE_HAIKU_MODEL,
      max_tokens: maxTokens,
      system: [
        {
          type: 'text',
          text: systemPrompt,
          cache_control: { type: 'ephemeral' },
        },
      ],
      messages: [{ role: 'user', content }],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Anthropic API error ${response.status}: ${body}`);
  }

  const json = (await response.json()) as {
    content: { type: string; text?: string }[];
    stop_reason: string | null;
  };
  const text = json.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text ?? '')
    .join('\n');
  return { text, stopReason: json.stop_reason };
}
