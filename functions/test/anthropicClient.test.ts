import { afterEach, describe, expect, it, vi } from 'vitest';
import { callClaude } from '../src/lib/anthropicClient';
import type { Env } from '../src/lib/env';

function makeEnv(apiKey: string): Env {
  return { ANTHROPIC_API_KEY: apiKey, FIREBASE_PROJECT_ID: 'demo-wanote' };
}

describe('callClaude mock fallback (no ANTHROPIC_API_KEY configured)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns a clearly-labeled mock response and never calls fetch when the key is unset', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const result = await callClaude({
      env: makeEnv(''),
      systemPrompt: 'You are a helpful assistant.',
      userText: 'こんにちは',
    });

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(result.text).toContain('MOCK RESPONSE');
    expect(result.text).toContain('こんにちは');
    expect(result.stopReason).toBe('mock');
  });

  it('treats a whitespace-only key as missing too', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const result = await callClaude({
      env: makeEnv('   '),
      systemPrompt: 'sys',
      userText: 'hi',
    });

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(result.text).toContain('MOCK RESPONSE');
  });

  it('notes when an image was attached but not analyzed', async () => {
    const result = await callClaude({
      env: makeEnv(''),
      systemPrompt: 'sys',
      userText: 'extract fields',
      image: { mediaType: 'image/png', base64Data: 'AAAA' },
    });

    expect(result.text).toContain('not analyzed in mock mode');
  });

  it('logs a warning so the mock path is visible server-side', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

    await callClaude({ env: makeEnv(''), systemPrompt: 'sys', userText: 'hi' });

    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toContain('ANTHROPIC_API_KEY is not set');
  });

  it('calls the real API and does not use the mock path when a key is set', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({ content: [{ type: 'text', text: 'real answer' }], stop_reason: 'end_turn' }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      ),
    );

    const result = await callClaude({
      env: makeEnv('sk-real-key'),
      systemPrompt: 'sys',
      userText: 'hi',
    });

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(result.text).toBe('real answer');
    expect(result.text).not.toContain('MOCK RESPONSE');
  });
});
