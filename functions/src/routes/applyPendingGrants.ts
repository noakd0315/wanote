import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import {
  commit,
  listDocuments,
  readTimestamp,
  type FirestoreEnv,
} from '../lib/firestoreClient';
import { PREMIUM_ENTITLEMENT_ID, REDEMPTION_DURATION } from '../lib/grantOrDefer';
import { grantPromotionalEntitlement, hasActiveEntitlement } from '../lib/revenueCatClient';

/**
 * POST /billing/apply-pending-grants -- delivers rewards that were earned
 * while the user already had premium.
 *
 * The client calls this when it notices premium has lapsed, and on start.
 * That call is a *hint*, never a fact: this route re-checks with RevenueCat
 * itself before granting anything. Trusting the client's word would put back
 * exactly the hole that made the redemption endpoint dangerous -- a
 * subscriber could claim to have lapsed and stack free months on top of the
 * plan they are already paying for.
 *
 * No request body: the uid comes from the verified ID token.
 */

const RATE_LIMIT = { maxCalls: 60, windowSeconds: 60 * 60 * 24 };

type ApplyPendingGrantsEnv = FirestoreEnv & RateLimitEnv;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

export async function handleApplyPendingGrants(
  request: Request,
  env: ApplyPendingGrantsEnv,
): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const rateLimit = await checkRateLimit(env, `apply-pending-grants:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many requests. Please try again later.' }, 429);
  }

  try {
    // The authoritative check. Anything the client believes about its own
    // subscription is irrelevant here.
    const stillPremium = await hasActiveEntitlement({
      env,
      appUserId: uid,
      entitlementIdentifier: PREMIUM_ENTITLEMENT_ID,
    });
    if (stillPremium) {
      return jsonResponse({ applied: 0, reason: 'stillSubscribed' }, 200);
    }

    const pending = await listDocuments(env, `users/${uid}/pending_grants`);
    const now = Date.now();

    // Oldest first, so the reward someone has been owed longest is the one
    // they get if anything goes wrong partway through.
    const applicable = pending
      .filter(({ doc }) => {
        if (readTimestamp(doc, 'appliedAt') !== null) return false;
        const expiresAt = readTimestamp(doc, 'expiresAt');
        // A grant with no expiry recorded is malformed; treat it as expired
        // rather than as eternal.
        if (expiresAt === null) return false;
        return new Date(expiresAt).getTime() > now;
      })
      .sort((a, b) => {
        const left = readTimestamp(a.doc, 'createdAt') ?? '';
        const right = readTimestamp(b.doc, 'createdAt') ?? '';
        return left.localeCompare(right);
      });

    let applied = 0;
    for (const { id } of applicable) {
      // One RevenueCat call per pending month. Marked applied immediately
      // after, so a failure mid-way leaves the rest still owed rather than
      // silently consumed.
      await grantPromotionalEntitlement({
        env,
        appUserId: uid,
        entitlementIdentifier: PREMIUM_ENTITLEMENT_ID,
        duration: REDEMPTION_DURATION,
      });
      await commit(env, null, [
        {
          path: `users/${uid}/pending_grants/${id}`,
          fields: { appliedAt: { timestampValue: new Date().toISOString() } },
          updateMask: ['appliedAt'],
          mustExist: true,
        },
      ]);
      applied += 1;
    }

    return jsonResponse({ applied }, 200);
  } catch (error) {
    console.error('[applyPendingGrants] failed', error);
    return jsonResponse({ error: 'Could not apply your pending rewards.' }, 502);
  }
}
