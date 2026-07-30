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

/** Thin wrapper around the Messages API. Every feature-specific route
 * (ocr.ts, consultation.ts, report.ts) builds its own system prompt and
 * calls this — the API key never leaves this Worker. */
export async function callClaude({
  env,
  systemPrompt,
  userText,
  image,
  maxTokens = 1024,
}: CallClaudeParams): Promise<ClaudeResult> {
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
