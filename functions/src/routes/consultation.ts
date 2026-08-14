import type { Env } from '../lib/env';
import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { callClaude } from '../lib/anthropicClient';
import type { OutputLanguage } from '../lib/outputLanguage';
import { outputLanguageInstruction, parseOutputLanguage } from '../lib/outputLanguage';

/**
 * POST /ai/consultation — spec section 6 (AI相談).
 *
 * Safety framing lives entirely in this system prompt so it can be sent with
 * `cache_control` (see lib/anthropicClient.ts) and reused across calls
 * without re-billing input tokens every time. The emergency-keyword
 * short-circuit itself happens client-side (features/ai's
 * EmergencyKeywordDetector) *before* this endpoint is ever called — this
 * route assumes it is only reached for non-emergency questions, but the
 * prompt still tells the model to recommend a vet visit whenever it is
 * unsure, as defense in depth.
 */
export function buildSystemPrompt(language: OutputLanguage): string {
  return `You are an AI health-guidance assistant for dog owners. Follow these rules strictly.

- You are not a veterinarian and you do not diagnose. Write so that it is clear your answer is guidance on whether and how soon to see a vet, not a diagnosis.
- Explain one to three common possible causes of the described signs, briefly.
- Always state which of these three levels the situation is closest to: safe to keep an eye on at home; should be seen by a vet soon; needs to be seen right now.
- If there is any indication at all that it may be urgent, do not suggest waiting and see -- recommend a vet visit clearly.
${outputLanguageInstruction(language)}
- Close with a short line noting that this is guidance, not a diagnosis.`;
}

export interface ReferencedRecordInput {
  recordId: string;
  recordType: string;
  label: string;
  tags: string[];
}

export interface ConsultationRequestBody {
  petId: string;
  questionText: string;
  referencedRecords: ReferencedRecordInput[];
  /** Language the *answer* should be written in. Defaults to Japanese so a
   * client that doesn't send it behaves exactly as before. */
  language: OutputLanguage;
}

/** Pure JSON-shaping/validation, factored out so it's testable without any
 * fetch/IO — see functions/test/consultation.test.ts. */
export function parseConsultationRequestBody(json: unknown): ConsultationRequestBody {
  if (typeof json !== 'object' || json === null) {
    throw new Error('Request body must be a JSON object.');
  }
  const body = json as Record<string, unknown>;

  if (typeof body.petId !== 'string' || body.petId.trim().length === 0) {
    throw new Error('petId is required.');
  }
  if (typeof body.questionText !== 'string' || body.questionText.trim().length === 0) {
    throw new Error('questionText is required.');
  }
  if (body.questionText.length > 2000) {
    throw new Error('questionText is too long (max 2000 characters).');
  }

  let referencedRecords: ReferencedRecordInput[] = [];
  if (body.referencedRecords !== undefined) {
    if (!Array.isArray(body.referencedRecords)) {
      throw new Error('referencedRecords must be an array.');
    }
    referencedRecords = body.referencedRecords.map(parseReferencedRecord);
  }

  return {
    petId: body.petId,
    questionText: body.questionText,
    referencedRecords,
    language: parseOutputLanguage(body.language),
  };
}

function parseReferencedRecord(raw: unknown): ReferencedRecordInput {
  if (typeof raw !== 'object' || raw === null) {
    throw new Error('Invalid referencedRecords entry.');
  }
  const record = raw as Record<string, unknown>;
  if (typeof record.recordId !== 'string' || typeof record.recordType !== 'string' || typeof record.label !== 'string') {
    throw new Error('Invalid referencedRecords entry shape.');
  }
  const tags = Array.isArray(record.tags)
    ? record.tags.filter((tag): tag is string => typeof tag === 'string')
    : [];
  return {
    recordId: record.recordId,
    recordType: record.recordType,
    label: record.label,
    tags,
  };
}

/** Pure prompt-building, also factored out for unit testing. */
export function buildConsultationUserPrompt(body: ConsultationRequestBody): string {
  // The owner's own question is passed through exactly as they typed it.
  // Only the scaffolding around it is ours to write, and that is English.
  const lines = [`Question from the owner: ${body.questionText}`];
  if (body.referencedRecords.length > 0) {
    lines.push('', 'Records the owner attached for context:');
    for (const record of body.referencedRecords) {
      const tagsSuffix = record.tags.length > 0 ? ` (tags: ${record.tags.join(', ')})` : '';
      lines.push(`- [${record.recordType}] ${record.label}${tagsSuffix}`);
    }
  }
  return lines.join('\n');
}

/** Abuse-protection ceiling on top of the free/ticket/subscription quota
 * that features/ai already enforces via AiUsageRepository in Firestore:
 * even an unlimited subscriber shouldn't be able to script thousands of
 * calls per hour. 10 calls / 60 minutes per user comfortably covers a real
 * consultation session (initial question + a couple of follow-ups) while
 * bounding worst-case cost — see spec section 9's "乱用対策". Revisit once
 * real usage data exists. */
const RATE_LIMIT = { maxCalls: 10, windowSeconds: 60 * 60 };

type ConsultationEnv = Env & RateLimitEnv;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function handleConsultation(request: Request, env: ConsultationEnv): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const rateLimit = await checkRateLimit(env, `consultation:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many consultation requests. Please try again later.' }, 429);
  }

  let body: ConsultationRequestBody;
  try {
    body = parseConsultationRequestBody(await request.json());
  } catch (err) {
    return jsonResponse({ error: err instanceof Error ? err.message : 'Invalid request body.' }, 400);
  }

  try {
    const result = await callClaude({
      env,
      systemPrompt: buildSystemPrompt(body.language),
      userText: buildConsultationUserPrompt(body),
      maxTokens: 768,
    });
    return jsonResponse({ responseText: result.text }, 200);
  } catch {
    return jsonResponse({ error: 'AI request failed. Please try again later.' }, 502);
  }
}
