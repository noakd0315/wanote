import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { commit, FirestoreError, type FirestoreEnv } from '../lib/firestoreClient';

/**
 * POST /billing/referral-code -- returns the caller's own referral code,
 * creating its `campaign_codes/{code}` document on first request.
 *
 * This moved off the client together with redemption. `campaign_codes` is
 * shared, not owned by anyone, so letting clients write there meant they
 * could mint codes -- and any rule permissive enough to allow the legitimate
 * self-referral create was also permissive enough to be worth attacking.
 * With both writers server-side, the collection is now closed to clients
 * entirely (see firestore.rules).
 *
 * No request body: the code is derived from the verified uid, so there is
 * nothing for the caller to choose.
 */

/** Mirrors lib/features/billing/domain/campaign_code_models.dart's
 * ReferralCodeGenerator.deriveFrom -- the same uid must always produce the
 * same code on both sides. */
const SHORT_ID_LENGTH = 8;

/** Mirrors FirestoreCampaignCodeRepository.referralMaxRedemptions. Referral
 * codes are not meant to be scarce; they just need *a* cap so the same
 * eligibility rules apply uniformly. */
const REFERRAL_MAX_REDEMPTIONS = 1000;

const RATE_LIMIT = { maxCalls: 60, windowSeconds: 60 * 60 * 24 };

type ReferralCodeEnv = FirestoreEnv & RateLimitEnv;

export function deriveReferralCode(uid: string): string {
  const shortId = uid.length <= SHORT_ID_LENGTH ? uid : uid.slice(0, SHORT_ID_LENGTH);
  return `REF-${shortId.toUpperCase()}`;
}

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function handleReferralCode(
  request: Request,
  env: ReferralCodeEnv,
): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const rateLimit = await checkRateLimit(env, `referral-code:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many requests. Please try again later.' }, 429);
  }

  const code = deriveReferralCode(uid);

  try {
    // Create-if-absent, with no prior read: the precondition does the work,
    // so a second caller racing the first simply gets the existing document
    // rather than resetting its redemption count to zero.
    await commit(env, null, [
      {
        path: `campaign_codes/${code}`,
        fields: {
          active: { booleanValue: true },
          maxRedemptions: { integerValue: String(REFERRAL_MAX_REDEMPTIONS) },
          redemptionCount: { integerValue: '0' },
          referrerUid: { stringValue: uid },
        },
        mustExist: false,
      },
    ]);
  } catch (error) {
    if (!(error instanceof FirestoreError) || !error.isFailedPrecondition) {
      console.error('[referralCode] could not ensure the referral code exists', error);
      return jsonResponse({ error: 'Could not load your referral code.' }, 502);
    }
    // Already exists, which is the normal case after the first call.
  }

  return jsonResponse({ code }, 200);
}
