import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import {
  commit,
  FirestoreError,
  getDocuments,
  readString,
  type FirestoreEnv,
} from '../lib/firestoreClient';

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

const SHORT_ID_LENGTH = 8;

/** How many codes to try before giving up. Only a collision consumes one, and
 * collisions are already vanishingly rare (see [referralCodeCandidates]), so
 * this exists to bound the loop rather than because it will be reached. */
const MAX_CODE_CANDIDATES = 5;

/** Matches the referral reward cap in
 * routes/grantPromotionalEntitlement.ts: the owner earns at most five
 * rewards, and the code is deactivated when they do, so a higher redemption
 * cap would only leave a code alive that can no longer pay its owner. */
const REFERRAL_MAX_REDEMPTIONS = 5;

const RATE_LIMIT = { maxCalls: 60, windowSeconds: 60 * 60 * 24 };

type ReferralCodeEnv = FirestoreEnv & RateLimitEnv;

export function deriveReferralCode(uid: string): string {
  const shortId = uid.length <= SHORT_ID_LENGTH ? uid : uid.slice(0, SHORT_ID_LENGTH);
  return `REF-${shortId.toUpperCase()}`;
}

/**
 * The codes [uid] may own, in the order they are tried.
 *
 * [deriveReferralCode] takes the first eight characters of the uid and
 * upper-cases them, so two uids can derive the same code -- Firebase uids are
 * case-sensitive, which means `abcdefgh…` and `ABCDEFGH…` collide outright.
 * It is rare (36^8 combinations), but the old code handled it by treating
 * "this document already exists" as "then it's yours": the second user's
 * referral code was really the first user's, so every friend they invited
 * credited a stranger, and their own counter never moved. Silently.
 *
 * The fix is that ownership is *checked* rather than assumed, and a taken
 * code falls through to the next candidate here.
 */
export function referralCodeCandidates(uid: string): string[] {
  const base = deriveReferralCode(uid);
  return Array.from({ length: MAX_CODE_CANDIDATES }, (_, i) =>
    i === 0 ? base : `${base}-${i + 1}`,
  );
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

  try {
    for (const code of referralCodeCandidates(uid)) {
      try {
        // Create-if-absent, with no prior read: the precondition does the
        // work, so a second caller racing the first simply gets the existing
        // document rather than resetting its redemption count to zero.
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
        return jsonResponse({ code }, 200);
      } catch (error) {
        if (!(error instanceof FirestoreError) || !error.isFailedPrecondition) throw error;
      }

      // The document already exists. Usually because this same user asked
      // before, which is the normal case after the first call -- but not
      // necessarily, so ask whose it is instead of assuming.
      const [existing] = await getDocuments(env, [`campaign_codes/${code}`]);
      if (readString(existing, 'referrerUid') === uid) {
        return jsonResponse({ code }, 200);
      }
      // Somebody else's. Try the next candidate.
    }

    console.error(
      `[referralCode] every candidate code is taken for uid=${uid}; ` +
        'this should be statistically impossible -- check deriveReferralCode.',
    );
    return jsonResponse({ error: 'Could not load your referral code.' }, 502);
  } catch (error) {
    console.error('[referralCode] could not ensure the referral code exists', error);
    return jsonResponse({ error: 'Could not load your referral code.' }, 502);
  }
}
