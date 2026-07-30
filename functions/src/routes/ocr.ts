import type { Env } from '../lib/env';
import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { callClaude, type AnthropicImageInput } from '../lib/anthropicClient';
import { OCR_SYSTEM_PROMPT, parseOcrModelOutput } from '../lib/ocrParsing';

/**
 * POST /ocr/certificate (spec 5.4 -- certificate AI-OCR).
 *
 * Request body: { image_base64: string, media_type: 'image/jpeg' | 'image/png' | 'image/webp' }
 * Headers: Authorization: Bearer <Firebase ID token>
 *
 * Response body: { extracted: OcrExtractedFields, confidence: number | null }
 *
 * The client (lib/features/medical/data/certificate_ocr_service.dart) has
 * already resized/compressed the image before it ever reaches this route
 * (spec 5.4 step 2) -- this route does not re-validate image dimensions,
 * only that a body was sent at all.
 */
export async function handleOcrCertificate(
  request: Request,
  env: Env & RateLimitEnv,
): Promise<Response> {
  let uid: string;
  try {
    const { uid: verifiedUid } = await verifyFirebaseToken(
      request.headers.get('authorization'),
      env,
    );
    uid = verifiedUid;
  } catch {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  // Spec section 9's "乱用対策": OCR is a low-frequency, per-certificate
  // action (a handful of times per pet per year), so 10/day/user is a
  // generous ceiling that only bites actual abuse, not normal use.
  const rateLimit = await checkRateLimit(env, `ocr:${uid}`, {
    maxCalls: 10,
    windowSeconds: 60 * 60 * 24,
  });
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Rate limit exceeded. Try again tomorrow.' }, 429);
  }

  let body: { image_base64?: unknown; media_type?: unknown };
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const imageBase64 = body.image_base64;
  const mediaType = body.media_type;
  if (typeof imageBase64 !== 'string' || imageBase64.length === 0) {
    return jsonResponse({ error: 'image_base64 is required' }, 400);
  }
  if (!isSupportedMediaType(mediaType)) {
    return jsonResponse(
      { error: 'media_type must be image/jpeg, image/png, or image/webp' },
      400,
    );
  }

  const image: AnthropicImageInput = {
    mediaType,
    base64Data: imageBase64,
  };

  let claudeText: string;
  try {
    const result = await callClaude({
      env,
      systemPrompt: OCR_SYSTEM_PROMPT,
      userText:
        'Extract the certificate fields as instructed and return only the JSON object.',
      image,
      maxTokens: 512,
    });
    claudeText = result.text;
  } catch (error) {
    return jsonResponse(
      { error: `OCR extraction failed: ${(error as Error).message}` },
      502,
    );
  }

  const { extracted, confidence } = parseOcrModelOutput(claudeText);
  return jsonResponse({ extracted, confidence }, 200);
}

function isSupportedMediaType(
  value: unknown,
): value is AnthropicImageInput['mediaType'] {
  return (
    value === 'image/jpeg' || value === 'image/png' || value === 'image/webp'
  );
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
