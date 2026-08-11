import { SignJWT, importPKCS8 } from 'jose';

import type { Env } from './env';

/**
 * Minimal Firestore REST client for the Worker.
 *
 * The Worker deliberately had no Firestore access, which is why every
 * redemption decision that needs stored state lived in the Flutter client --
 * where it was not a decision at all, just a suggestion an attacker could
 * skip. Granting premium has to be authorized against data only the server
 * can trust, so the server has to be able to read it.
 *
 * Only what the campaign-code flow needs: read documents inside a
 * transaction, and commit writes with preconditions. Deliberately not a
 * general-purpose SDK.
 *
 * Two modes, chosen by whether an emulator host is configured:
 *   - local dev: the Firestore emulator, which needs no credentials;
 *   - production: firestore.googleapis.com with an OAuth2 access token
 *     minted from a service account.
 */

/** Firestore's REST representation of a document field. */
export type FirestoreValue =
  | { stringValue: string }
  | { integerValue: string }
  | { booleanValue: boolean }
  | { timestampValue: string }
  | { nullValue: null };

export interface FirestoreDocument {
  name?: string;
  fields?: Record<string, FirestoreValue>;
}

/** Reads a field as a string, or null when absent/of another type. */
export function readString(doc: FirestoreDocument | null, field: string): string | null {
  const value = doc?.fields?.[field];
  return value && 'stringValue' in value ? value.stringValue : null;
}

/** Reads a field as an integer. Firestore returns integers as strings. */
export function readInt(doc: FirestoreDocument | null, field: string): number | null {
  const value = doc?.fields?.[field];
  if (!value) return null;
  if ('integerValue' in value) return Number.parseInt(value.integerValue, 10);
  return null;
}

/** Reads a timestamp field as its ISO-8601 string. Separate from
 * [readString] because Firestore stores these as `timestampValue`, and
 * reading one with readString silently yields null -- which for a field like
 * `appliedAt` reads as "not yet applied". */
export function readTimestamp(doc: FirestoreDocument | null, field: string): string | null {
  const value = doc?.fields?.[field];
  return value && 'timestampValue' in value ? value.timestampValue : null;
}

export function readBool(doc: FirestoreDocument | null, field: string): boolean | null {
  const value = doc?.fields?.[field];
  return value && 'booleanValue' in value ? value.booleanValue : null;
}

export interface FirestoreEnv extends Env {
  /** Host:port of the Firestore emulator, e.g. `localhost:8081`. Set only in
   * functions/.dev.vars for local dev; never in a real deployment. */
  FIRESTORE_EMULATOR_HOST?: string;
  /** Service-account credentials, needed only when there is no emulator.
   * Set with `wrangler secret put`; never committed. */
  FIREBASE_CLIENT_EMAIL?: string;
  /** PEM private key of the service account, newlines as literal `\n`. */
  FIREBASE_PRIVATE_KEY?: string;
}

/** Access tokens last an hour; re-minting one per request would add a
 * round trip to Google to every redemption. Module scope is per-isolate,
 * which is the right lifetime for this. */
let cachedToken: { token: string; expiresAtMs: number } | null = null;

async function accessToken(env: FirestoreEnv): Promise<string | null> {
  // The emulator applies security rules to REST callers just like a client,
  // so an unauthenticated request is denied by our own rules. `owner` is the
  // emulator's documented admin credential, which puts the Worker in the same
  // position it has in production: a service account bypasses rules entirely.
  if (env.FIRESTORE_EMULATOR_HOST) return 'owner';

  const clientEmail = env.FIREBASE_CLIENT_EMAIL;
  const privateKeyPem = env.FIREBASE_PRIVATE_KEY;
  if (!clientEmail || !privateKeyPem) {
    throw new Error(
      'Firestore access requires FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY ' +
        '(or FIRESTORE_EMULATOR_HOST for local dev). See functions/.dev.vars.example.',
    );
  }

  const now = Date.now();
  if (cachedToken && cachedToken.expiresAtMs > now + 60_000) {
    return cachedToken.token;
  }

  // `wrangler secret` values are single-line, so the PEM arrives with
  // literal backslash-n rather than real newlines.
  const key = await importPKCS8(privateKeyPem.replace(/\\n/g, '\n'), 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/datastore',
  })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Failed to mint a Google access token: ${response.status}`);
  }
  const body = (await response.json()) as { access_token: string; expires_in: number };
  cachedToken = {
    token: body.access_token,
    expiresAtMs: now + body.expires_in * 1000,
  };
  return cachedToken.token;
}

function databaseUrl(env: FirestoreEnv): string {
  const base = env.FIRESTORE_EMULATOR_HOST
    ? `http://${env.FIRESTORE_EMULATOR_HOST}`
    : 'https://firestore.googleapis.com';
  return `${base}/v1/${databaseName(env)}`;
}

/** The database's *resource* name. Firestore identifies documents by these,
 * not by URL -- passing a URL to batchGet is rejected outright. */
function databaseName(env: FirestoreEnv): string {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)`;
}

async function firestoreFetch(
  env: FirestoreEnv,
  path: string,
  init: RequestInit,
): Promise<unknown> {
  const token = await accessToken(env);
  const response = await fetch(`${databaseUrl(env)}${path}`, {
    ...init,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new FirestoreError(response.status, detail);
  }
  return response.json();
}

export class FirestoreError extends Error {
  constructor(
    readonly status: number,
    readonly detail: string,
  ) {
    super(`Firestore request failed: ${status}`);
  }

  /** A transaction that lost a race. Firestore reports these as 409/ABORTED,
   * and they mean "retry", not "the caller did something wrong". */
  get isAborted(): boolean {
    return this.status === 409 || this.detail.includes('ABORTED');
  }

  /** A write whose `currentDocument` precondition did not hold -- e.g.
   * create-if-absent losing to a document that already exists. */
  get isFailedPrecondition(): boolean {
    return this.detail.includes('FAILED_PRECONDITION') || this.detail.includes('ALREADY_EXISTS');
  }
}

/** Opens a read-write transaction and returns its id. */
export async function beginTransaction(env: FirestoreEnv): Promise<string> {
  const result = (await firestoreFetch(env, '/documents:beginTransaction', {
    method: 'POST',
    body: JSON.stringify({ options: { readWrite: {} } }),
  })) as { transaction: string };
  return result.transaction;
}

/**
 * Reads several documents inside [transaction]. Missing documents come back
 * as null in the same order as [paths], which the caller needs: "no such
 * campaign code" and "no redemption marker" are both meaningful answers.
 *
 * [paths] are relative to the database root, e.g. `campaign_codes/ABC`.
 */
export async function getDocuments(
  env: FirestoreEnv,
  paths: string[],
  transaction?: string,
): Promise<(FirestoreDocument | null)[]> {
  const prefix = `${databaseName(env)}/documents/`;
  const result = (await firestoreFetch(env, '/documents:batchGet', {
    method: 'POST',
    body: JSON.stringify({
      documents: paths.map((path) => `${prefix}${path}`),
      ...(transaction ? { transaction } : {}),
    }),
  })) as { found?: FirestoreDocument; missing?: string }[];

  // batchGet does not promise the response order matches the request, so
  // index the results by name rather than trusting position.
  const byPath = new Map<string, FirestoreDocument | null>();
  for (const entry of result) {
    if (entry.found?.name) {
      byPath.set(entry.found.name.slice(entry.found.name.indexOf('/documents/') + 11), entry.found);
    } else if (entry.missing) {
      byPath.set(entry.missing.slice(entry.missing.indexOf('/documents/') + 11), null);
    }
  }
  return paths.map((path) => byPath.get(path) ?? null);
}

export interface FirestoreWrite {
  path: string;
  fields: Record<string, FirestoreValue>;
  /** Field names to write; others on the document are left alone. Omit to
   * replace the whole document. */
  updateMask?: string[];
  /** Fails the commit unless the document's existence matches. */
  mustExist?: boolean;
}

/** Commits [writes] atomically, or throws. Pass a null [transaction] for a
 * standalone write that needs no prior read -- the preconditions on each
 * write still apply. */
export async function commit(
  env: FirestoreEnv,
  transaction: string | null,
  writes: FirestoreWrite[],
): Promise<void> {
  const prefix = `${databaseName(env)}/documents/`;
  await firestoreFetch(env, '/documents:commit', {
    method: 'POST',
    body: JSON.stringify({
      ...(transaction ? { transaction } : {}),
      writes: writes.map((write) => ({
        update: { name: `${prefix}${write.path}`, fields: write.fields },
        ...(write.updateMask ? { updateMask: { fieldPaths: write.updateMask } } : {}),
        ...(write.mustExist === undefined
          ? {}
          : { currentDocument: { exists: write.mustExist } }),
      })),
    }),
  });
}

/** Abandons a transaction opened by [beginTransaction]. */
export async function rollback(env: FirestoreEnv, transaction: string): Promise<void> {
  await firestoreFetch(env, '/documents:rollback', {
    method: 'POST',
    body: JSON.stringify({ transaction }),
  });
}

/**
 * Lists every document in [collectionPath]. Used for a user's pending
 * grants, which is a handful of documents at most -- deliberately not
 * paginated, and not suitable for a collection that could grow large.
 */
export async function listDocuments(
  env: FirestoreEnv,
  collectionPath: string,
): Promise<{ id: string; doc: FirestoreDocument }[]> {
  const result = (await firestoreFetch(env, `/documents/${collectionPath}?pageSize=100`, {
    method: 'GET',
  })) as { documents?: FirestoreDocument[] };
  return (result.documents ?? []).map((doc) => ({
    id: (doc.name ?? '').split('/').pop() ?? '',
    doc,
  }));
}
