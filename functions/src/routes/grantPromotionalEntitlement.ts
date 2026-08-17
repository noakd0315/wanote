import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { grantOrDefer } from '../lib/grantOrDefer';
import {
  beginTransaction,
  commit,
  FirestoreError,
  getDocuments,
  readBool,
  readInt,
  readString,
  rollback,
  type FirestoreEnv,
  type FirestoreWrite,
} from '../lib/firestoreClient';
import { evaluateEligibility, type CampaignCode } from '../lib/campaignCodeEligibility';

/**
 * POST /billing/grant-promotional-entitlement -- campaign-code / referral-code
 * redemption.
 *
 * Body: `{ "code": "SUMMER2026" }`
 *
 * This route used to take no body at all: it verified the caller's Firebase
 * ID token and then granted a month of premium, trusting the client to have
 * checked that a code was actually redeemed. Anyone with a free account could
 * therefore call it directly and grant themselves premium, repeatedly, with
 * no code -- the redemption records and caps in Firestore were never
 * consulted, because the Worker could not see Firestore.
 *
 * Now the whole decision happens here: the code is looked up, eligibility is
 * evaluated server-side, and the redemption is recorded in the same Firestore
 * transaction that reads it, so two concurrent redemptions cannot both take
 * the last slot of a capped code.
 *
 * Ordering note: the redemption is committed BEFORE RevenueCat is called. If
 * the grant then fails the user is told to try again while their marker is
 * already written, which costs them one redemption of that code -- annoying,
 * and reported honestly. The other order is worse: granting first means a
 * crash in between hands out premium with nothing recorded, which is exactly
 * the unbounded-grant hole being closed.
 */

/** How many referrals one user can be rewarded for, ever. PM decision.
 *
 * Counted per USER rather than per code: a cap on the code would become
 * 5-per-code the moment anyone holds more than one, which is a change we
 * should be able to make without reopening the abuse ceiling. It is also
 * what bounds the damage from someone referring themselves with throwaway
 * accounts -- five months, not unlimited. */
const MAX_REFERRAL_REWARDS = 5;

/** Abuse ceiling on top of the per-code rules. Redemption is now genuinely
 * gated by the code's own cap and the per-user marker, so this only limits
 * how fast someone can probe codes they do not have. */
const RATE_LIMIT = { maxCalls: 20, windowSeconds: 60 * 60 * 24 };

/** Matches the client's own input constraints; anything longer is not a code
 * anyone typed. */
const MAX_CODE_LENGTH = 64;

type GrantPromotionalEntitlementEnv = FirestoreEnv & RateLimitEnv;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

export async function handleGrantPromotionalEntitlement(
  request: Request,
  env: GrantPromotionalEntitlementEnv,
): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  let code: string;
  try {
    const body = (await request.json()) as { code?: unknown };
    if (typeof body.code !== 'string') {
      return jsonResponse({ error: 'A code is required.' }, 400);
    }
    code = body.code.trim().toUpperCase();
    if (code.length === 0 || code.length > MAX_CODE_LENGTH) {
      return jsonResponse({ error: 'A code is required.' }, 400);
    }
    // Document ids cannot contain a slash, and letting one through would
    // address a different collection entirely.
    if (code.includes('/')) {
      return jsonResponse({ error: 'A code is required.' }, 400);
    }
  } catch {
    return jsonResponse({ error: 'A code is required.' }, 400);
  }

  const rateLimit = await checkRateLimit(env, `grant-promotional-entitlement:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many redemption requests. Please try again later.' }, 429);
  }

  const codePath = `campaign_codes/${code}`;
  const markerPath = `users/${uid}/redeemed_codes/${code}`;

  const referrerWrites: FirestoreWrite[] = [];
  let rewardedReferrerUid: string | null = null;

  let transaction: string;
  try {
    transaction = await beginTransaction(env);
  } catch {
    return jsonResponse({ error: 'Could not reach the redemption service.' }, 502);
  }

  try {
    const [codeDoc, markerDoc] = await getDocuments(env, [codePath, markerPath], transaction);

    const campaignCode: CampaignCode | null =
      codeDoc === null
        ? null
        : {
            active: readBool(codeDoc, 'active') ?? false,
            maxRedemptions: readInt(codeDoc, 'maxRedemptions') ?? 0,
            redemptionCount: readInt(codeDoc, 'redemptionCount') ?? 0,
            referrerUid: readString(codeDoc, 'referrerUid'),
          };

    const eligibility = evaluateEligibility({
      code: campaignCode,
      alreadyRedeemedByUser: markerDoc !== null,
      uid,
    });
    if (!eligibility.eligible) {
      await rollback(env, transaction);
      return jsonResponse({ granted: false, reason: eligibility.reason }, 200);
    }

    // The referrer's reward is decided in the SAME transaction that records
    // the redemption, so their counter cannot be advanced twice by two
    // redemptions racing, and the code cannot be deactivated without the
    // redemption that triggered it also landing.
    const referrerUid = campaignCode!.referrerUid;
    let rewardReferrer = false;
    if (referrerUid !== null && referrerUid !== uid) {
      const [rewardsDoc] = await getDocuments(
        env,
        [`users/${referrerUid}/rewards/referral`],
        transaction,
      );
      const rewardedCount = readInt(rewardsDoc, 'rewardedCount') ?? 0;
      rewardReferrer = rewardedCount < MAX_REFERRAL_REWARDS;
      if (rewardReferrer) {
        referrerWrites.push({
          path: `users/${referrerUid}/rewards/referral`,
          fields: {
            rewardedCount: { integerValue: String(rewardedCount + 1) },
            updatedAt: { timestampValue: new Date().toISOString() },
          },
          updateMask: ['rewardedCount', 'updatedAt'],
        });
        // Retiring the code at the cap is what stops a referral link living
        // on as a free-month generator once its owner stops earning from it
        // (PM: 不正リスクの軽減).
        if (rewardedCount + 1 >= MAX_REFERRAL_REWARDS) {
          referrerWrites.push({
            path: codePath,
            fields: { active: { booleanValue: false } },
            updateMask: ['active'],
            mustExist: true,
          });
        }
      }
    }

    await commit(env, transaction, [
      {
        path: codePath,
        // updateMask keeps this to the counter -- a whole-document write
        // would silently drop referrerUid and the cap.
        fields: {
          redemptionCount: { integerValue: String(campaignCode!.redemptionCount + 1) },
        },
        updateMask: ['redemptionCount'],
        mustExist: true,
      },
      {
        path: markerPath,
        fields: { redeemedAt: { timestampValue: new Date().toISOString() } },
        mustExist: false,
      },
      ...referrerWrites,
    ]);
    rewardedReferrerUid = rewardReferrer ? referrerUid : null;
  } catch (error) {
    // A lost race reads as "someone else took the slot", which is a normal
    // outcome for a capped code rather than a server fault.
    if (error instanceof FirestoreError && error.isAborted) {
      return jsonResponse({ granted: false, reason: 'redemptionCapReached' }, 200);
    }
    console.error('[grantPromotionalEntitlement] redemption failed', error);
    return jsonResponse({ error: 'Could not complete the redemption. Please try again.' }, 502);
  }

  let outcome: 'granted' | 'deferred';
  try {
    outcome = await grantOrDefer({
      env,
      uid,
      reason: 'redemption',
      idempotencyKey: `redemption-${code}`,
    });
  } catch (error) {
    console.error('[grantPromotionalEntitlement] entitlement grant failed', error);
    return jsonResponse(
      { error: 'Failed to grant promotional entitlement. Please try again later.' },
      502,
    );
  }

  // The referrer's reward is best-effort on purpose: the person waiting on
  // this response is the redeemer, and failing their redemption because
  // somebody else's reward could not be delivered would be the wrong trade.
  // The counter is already committed, so a failure here is a reward owed --
  // logged for the operator to make good (PM decision).
  if (rewardedReferrerUid !== null) {
    try {
      await grantOrDefer({
        env,
        uid: rewardedReferrerUid,
        reason: 'referral',
        idempotencyKey: `referral-${code}-${uid}`,
      });
    } catch (error) {
      console.error(
        `[grantPromotionalEntitlement] REFERRAL REWARD FAILED referrerUid=${rewardedReferrerUid} ` +
          `code=${code} redeemedBy=${uid} at=${new Date().toISOString()}`,
        error,
      );
    }
  }

  return jsonResponse({ granted: true, deferred: outcome === 'deferred' }, 200);
}
