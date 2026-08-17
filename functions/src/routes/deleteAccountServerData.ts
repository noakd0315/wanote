import type { RateLimitEnv } from '../lib/rateLimiter';
import { checkRateLimit } from '../lib/rateLimiter';
import { verifyFirebaseToken } from '../lib/verifyFirebaseToken';
import {
  deleteDocuments,
  getDocuments,
  listDocuments,
  readString,
  type FirestoreEnv,
} from '../lib/firestoreClient';
import { deleteSubscriber } from '../lib/revenueCatClient';
import { referralCodeCandidates } from './referralCode';

/**
 * POST /account/delete-server-data -- erases the parts of an account that
 * only the backend may touch, as one step of in-app account deletion.
 *
 * The client sweeps its own documents and files directly; it cannot sweep
 * these. firestore.rules denies clients even a read of `rewards`,
 * `pending_grants` and `redeemed_codes`, and closes `campaign_codes`
 * entirely -- deliberately, since a client able to delete its own redemption
 * marker could redeem the same code twice. So the collections that exist
 * *because* clients aren't trusted with them are exactly the ones that would
 * otherwise survive "delete my account", each still holding the uid.
 *
 * No request body: the uid comes from the verified ID token, so this can
 * only ever delete the caller's own data.
 *
 * Idempotent. Deleting an absent document is not an error, so a client that
 * retries after a partial failure simply finishes the job.
 */

/** Deletion is rare but must never be the thing that fails. Generous enough
 * that retrying a flaky attempt is never blocked, low enough that it can't
 * be used to spin Firestore writes. */
const RATE_LIMIT = { maxCalls: 20, windowSeconds: 60 * 60 };

/** Account-level collections written only by the Worker. */
const SERVER_OWNED_COLLECTIONS = ['rewards', 'pending_grants', 'redeemed_codes'];

type DeleteAccountServerDataEnv = FirestoreEnv & RateLimitEnv;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

export async function handleDeleteAccountServerData(
  request: Request,
  env: DeleteAccountServerDataEnv,
): Promise<Response> {
  let uid: string;
  try {
    ({ uid } = await verifyFirebaseToken(request.headers.get('authorization'), env));
  } catch {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const rateLimit = await checkRateLimit(env, `delete-account:${uid}`, RATE_LIMIT);
  if (!rateLimit.allowed) {
    return jsonResponse({ error: 'Too many requests. Please try again later.' }, 429);
  }

  try {
    // RevenueCat first, so a failure here aborts before anything is touched
    // and leaves the account entirely intact for the retry.
    //
    // It holds the same uid the app signs in with, next to the purchase
    // history (billing_repository.dart calls `Purchases.logIn(uid)`), and the
    // privacy policy names RevenueCat as a processor -- so an account
    // deletion that skipped it would be telling the user something untrue.
    // Deleting a subscriber does NOT cancel their store subscription; only
    // the user can do that, which is what the deletion screen says.
    await deleteSubscriber({ env, appUserId: uid });

    const paths: string[] = [];

    for (const collection of SERVER_OWNED_COLLECTIONS) {
      const documents = await listDocuments(env, `users/${uid}/${collection}`);
      for (const { id } of documents) {
        paths.push(`users/${uid}/${collection}/${id}`);
      }
    }

    // The user's own referral code, which stores their uid as `referrerUid`.
    //
    // Every candidate is checked rather than just the first, and ownership is
    // verified rather than assumed: deriveReferralCode() uses only the first
    // eight characters of the uid, so a user who lost the race for their
    // primary code owns a `-2` one instead (see referralCodeCandidates).
    // Deleting unconditionally would let one account destroy another's
    // referral code simply by deleting itself.
    const candidates = referralCodeCandidates(uid);
    const codeDocs = await getDocuments(
      env,
      candidates.map((code) => `campaign_codes/${code}`),
    );
    candidates.forEach((code, i) => {
      if (readString(codeDocs[i], 'referrerUid') === uid) {
        paths.push(`campaign_codes/${code}`);
      }
    });

    await deleteDocuments(env, paths);

    return jsonResponse({ deleted: paths.length }, 200);
  } catch (error) {
    console.error('[deleteAccountServerData] failed', error);
    return jsonResponse({ error: 'Could not delete your account data.' }, 502);
  }
}
