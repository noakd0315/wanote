import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import { grantPromotionalEntitlement } from '../lib/revenueCatClient';
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

/** lib/features/billing/domain/product_ids.dart's EntitlementIds.premium.
 * Kept as a plain string here (rather than importing across the Dart/TS
 * boundary) -- update both together if the RevenueCat dashboard's
 * entitlement identifier ever changes. */
const PREMIUM_ENTITLEMENT_ID = 'premium';

/** "1ヶ月無料" (1 month of premium access), per the PM's explicit spec for
 * this feature. */
const REDEMPTION_DURATION = 'monthly';

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
    headers: { 'content-type': 'application/json' },
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
    ]);
  } catch (error) {
    // A lost race reads as "someone else took the slot", which is a normal
    // outcome for a capped code rather than a server fault.
    if (error instanceof FirestoreError && error.isAborted) {
      return jsonResponse({ granted: false, reason: 'redemptionCapReached' }, 200);
    }
    console.error('[grantPromotionalEntitlement] redemption failed', error);
    return jsonResponse({ error: 'Could not complete the redemption. Please try again.' }, 502);
  }

  try {
    const result = await grantPromotionalEntitlement({
      env,
      appUserId: uid,
      entitlementIdentifier: PREMIUM_ENTITLEMENT_ID,
      duration: REDEMPTION_DURATION,
    });
    return jsonResponse({ granted: result.granted }, 200);
  } catch (error) {
    console.error('[grantPromotionalEntitlement] entitlement grant failed', error);
    return jsonResponse(
      { error: 'Failed to grant promotional entitlement. Please try again later.' },
      502,
    );
  }
}
