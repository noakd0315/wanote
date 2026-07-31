import { describe, expect, it } from 'vitest';
import { verifyFirebaseToken } from '../src/lib/verifyFirebaseToken';
import type { Env } from '../src/lib/env';

const PROJECT_ID = 'demo-wanote';

function base64url(input: string): string {
  return Buffer.from(input, 'utf8').toString('base64url');
}

/** Builds an unsigned JWT shaped like what the Firebase Auth Emulator issues
 * (alg "none", empty signature segment) -- see
 * https://firebase.google.com/docs/emulator-suite/connect_auth#id_tokens. */
function makeEmulatorToken(payload: Record<string, unknown>): string {
  const header = base64url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const body = base64url(JSON.stringify(payload));
  return `${header}.${body}.`;
}

const emulatorEnv: Env = {
  ANTHROPIC_API_KEY: '',
  FIREBASE_PROJECT_ID: PROJECT_ID,
  FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
};

describe('verifyFirebaseToken', () => {
  it('throws when the Authorization header is missing or not a Bearer token', async () => {
    await expect(verifyFirebaseToken(null, emulatorEnv)).rejects.toThrow('Missing bearer token.');
    await expect(verifyFirebaseToken('Basic abc', emulatorEnv)).rejects.toThrow(
      'Missing bearer token.',
    );
  });

  describe('emulator mode (FIREBASE_AUTH_EMULATOR_HOST set)', () => {
    it('accepts an unsigned emulator token with matching issuer/audience and returns its uid', async () => {
      const token = makeEmulatorToken({
        iss: `https://securetoken.google.com/${PROJECT_ID}`,
        aud: PROJECT_ID,
        sub: 'test-user-123',
      });

      await expect(
        verifyFirebaseToken(`Bearer ${token}`, emulatorEnv),
      ).resolves.toEqual({ uid: 'test-user-123' });
    });

    it('rejects a token with the wrong issuer', async () => {
      const token = makeEmulatorToken({
        iss: 'https://securetoken.google.com/some-other-project',
        aud: PROJECT_ID,
        sub: 'test-user-123',
      });

      await expect(verifyFirebaseToken(`Bearer ${token}`, emulatorEnv)).rejects.toThrow(
        'Unexpected token issuer.',
      );
    });

    it('rejects a token with the wrong audience', async () => {
      const token = makeEmulatorToken({
        iss: `https://securetoken.google.com/${PROJECT_ID}`,
        aud: 'some-other-project',
        sub: 'test-user-123',
      });

      await expect(verifyFirebaseToken(`Bearer ${token}`, emulatorEnv)).rejects.toThrow(
        'Unexpected token audience.',
      );
    });

    it('rejects a token with no sub claim', async () => {
      const token = makeEmulatorToken({
        iss: `https://securetoken.google.com/${PROJECT_ID}`,
        aud: PROJECT_ID,
      });

      await expect(verifyFirebaseToken(`Bearer ${token}`, emulatorEnv)).rejects.toThrow(
        'Token payload missing sub claim.',
      );
    });
  });
});
