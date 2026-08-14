import type { Env } from '../lib/env';
import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { callClaude } from '../lib/anthropicClient';
import type { OutputLanguage } from '../lib/outputLanguage';
import { outputLanguageInstruction, parseOutputLanguage } from '../lib/outputLanguage';

/**
 * POST /ai/report — spec section 7 (AI健康レポート・グラフ化).
 *
 * Per spec 7.4, report generation is meant to be a monthly batch job, not
 * on-demand/real-time, to keep AI cost bounded. This route is written so a
 * future Cloudflare Cron Trigger can call it directly (it only needs
 * `weightSamples`/`toiletCountsByDay` for one pet + period, not a live user
 * session) — but for now it is invoked directly by the Flutter app's
 * "generate now" button. See this feature's agent report for the
 * follow-up-infra note on wiring an actual cron trigger, and for the
 * premium-only gating decision (enforced client-side in
 * lib/features/ai/presentation/report_screen.dart via
 * AiUsageStatus.hasUnlimitedSubscription — this route does not re-check
 * billing state itself, since Cloudflare Workers here has no direct
 * Firestore access; see the "open questions" section of that report).
 */
export function buildSystemPrompt(language: OutputLanguage): string {
  return `You write a monthly summary of a dog's health records. Follow these rules strictly.

- Base the summary only on the weight and toilet-count figures supplied. Do not speculate about diagnoses or name conditions.
- Include the actual numbers, e.g. "weight went up/down by N kg this month" or "toilet visits were N more/fewer than last month".
- If anything stands out -- a sharp change in weight, a large change in toilet frequency -- mention it as a reason to consider a vet visit.
- Close with a short line noting that this is guidance, not a medical diagnosis.
${outputLanguageInstruction(language)}`;
}

export interface WeightSampleInput {
  date: string;
  weightKg: number;
}

export interface ToiletDayCountInput {
  date: string;
  count: number;
}

export interface ReportRequestBody {
  petId: string;
  periodStart: string;
  periodEnd: string;
  weightSamples: WeightSampleInput[];
  toiletCountsByDay: ToiletDayCountInput[];
  /** Language the summary should be written in. Defaults to Japanese. */
  language: OutputLanguage;
}

/** Pure JSON-shaping/validation — see functions/test/report.test.ts. */
export function parseReportRequestBody(json: unknown): ReportRequestBody {
  if (typeof json !== 'object' || json === null) {
    throw new Error('Request body must be a JSON object.');
  }
  const body = json as Record<string, unknown>;

  if (typeof body.petId !== 'string' || body.petId.trim().length === 0) {
    throw new Error('petId is required.');
  }
  if (typeof body.periodStart !== 'string' || typeof body.periodEnd !== 'string') {
    throw new Error('periodStart and periodEnd are required.');
  }

  return {
    petId: body.petId,
    periodStart: body.periodStart,
    periodEnd: body.periodEnd,
    weightSamples: parseWeightSamples(body.weightSamples),
    toiletCountsByDay: parseToiletCounts(body.toiletCountsByDay),
    language: parseOutputLanguage(body.language),
  };
}

function parseWeightSamples(raw: unknown): WeightSampleInput[] {
  if (raw === undefined) return [];
  if (!Array.isArray(raw)) throw new Error('weightSamples must be an array.');
  return raw.map((entry) => {
    if (typeof entry !== 'object' || entry === null) throw new Error('Invalid weightSamples entry.');
    const e = entry as Record<string, unknown>;
    if (typeof e.date !== 'string' || typeof e.weightKg !== 'number') {
      throw new Error('Invalid weightSamples entry shape.');
    }
    return { date: e.date, weightKg: e.weightKg };
  });
}

function parseToiletCounts(raw: unknown): ToiletDayCountInput[] {
  if (raw === undefined) return [];
  if (!Array.isArray(raw)) throw new Error('toiletCountsByDay must be an array.');
  return raw.map((entry) => {
    if (typeof entry !== 'object' || entry === null) throw new Error('Invalid toiletCountsByDay entry.');
    const e = entry as Record<string, unknown>;
    if (typeof e.date !== 'string' || typeof e.count !== 'number') {
      throw new Error('Invalid toiletCountsByDay entry shape.');
    }
    return { date: e.date, count: e.count };
  });
}

export interface ReportStatsSummary {
  weightStartKg: number | null;
  weightEndKg: number | null;
  weightChangeKg: number | null;
  toiletTotalCount: number;
  toiletAveragePerDay: number;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

/** Pure aggregation over the raw samples, factored out so the arithmetic is
 * unit-testable independent of the Anthropic call. */
export function summarizeReportStats(body: ReportRequestBody): ReportStatsSummary {
  const { weightSamples, toiletCountsByDay } = body;
  const weightStartKg = weightSamples.length > 0 ? weightSamples[0].weightKg : null;
  const weightEndKg = weightSamples.length > 0 ? weightSamples[weightSamples.length - 1].weightKg : null;
  const weightChangeKg =
    weightStartKg !== null && weightEndKg !== null ? round1(weightEndKg - weightStartKg) : null;

  const toiletTotalCount = toiletCountsByDay.reduce((sum, day) => sum + day.count, 0);
  const toiletAveragePerDay =
    toiletCountsByDay.length > 0 ? round1(toiletTotalCount / toiletCountsByDay.length) : 0;

  return { weightStartKg, weightEndKg, weightChangeKg, toiletTotalCount, toiletAveragePerDay };
}

/** Pure prompt-building over the summarized stats. */
export function buildReportUserPrompt(body: ReportRequestBody): string {
  const stats = summarizeReportStats(body);
  const weightLine =
    stats.weightStartKg !== null && stats.weightEndKg !== null
      ? `Weight: ${stats.weightStartKg}kg -> ${stats.weightEndKg}kg (change: ${stats.weightChangeKg}kg)`
      : 'Weight: no weight records in this period.';
  const toiletLine = `Toilet records: ${stats.toiletTotalCount} in total (${stats.toiletAveragePerDay} per day on average)`;

  return [
    `Period: ${body.periodStart} to ${body.periodEnd}`,
    weightLine,
    toiletLine,
    '',
    'Write the monthly health summary for the owner from the figures above.',
  ].join('\n');
}

/** Abuse-protection ceiling. Spec 7.4 wants this to normally run as a
 * once-a-month batch job, so on-demand calls should be rare; 3 calls / 24h
 * per user is generous slack for retries or checking multiple pets while
 * still bounding a runaway client. Revisit once the batch job exists and
 * on-demand generation becomes the exception rather than the only path. */
const RATE_LIMIT = { maxCalls: 3, windowSeconds: 24 * 60 * 60 };

type ReportEnv = Env & RateLimitEnv;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function handleReport(request: Request, env: ReportEnv): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const rateLimit = await checkRateLimit(env, `report:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many report requests. Please try again later.' }, 429);
  }

  let body: ReportRequestBody;
  try {
    body = parseReportRequestBody(await request.json());
  } catch (err) {
    return jsonResponse({ error: err instanceof Error ? err.message : 'Invalid request body.' }, 400);
  }

  try {
    const result = await callClaude({
      env,
      systemPrompt: buildSystemPrompt(body.language),
      userText: buildReportUserPrompt(body),
      maxTokens: 768,
    });
    return jsonResponse({ responseText: result.text }, 200);
  } catch {
    return jsonResponse({ error: 'AI request failed. Please try again later.' }, 502);
  }
}
