import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

// Access-control tests for firestore.rules, run against the Firestore
// emulator that docker-compose already publishes on 8081.
//
// These exist because the rules are the *only* thing standing between one
// owner's medical records and everyone else: the Firestore endpoint is public
// infrastructure, and the API key embedded in the app is an identifier, not a
// secret. A mistake here is invisible in the app -- it keeps working
// perfectly for the owner while quietly being readable by anyone.
//
// Requires the emulators to be up: `docker compose up -d`.

const OWNER = 'owner-uid';
const OTHER = 'intruder-uid';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    // A *different* project id from the app's `demo-wanote`. The emulator
    // keeps projects separate, and clearFirestore() below wipes the project
    // it is given -- pointing these tests at the app's own project would
    // delete the local development data every run.
    projectId: 'demo-wanote-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8081,
    },
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

/** Firestore as the owner / as another signed-in user / as a signed-out one. */
const asOwner = () => testEnv.authenticatedContext(OWNER).firestore();
const asOther = () => testEnv.authenticatedContext(OTHER).firestore();
const asAnon = () => testEnv.unauthenticatedContext().firestore();

/** Seeds a document with the rules switched off, the way real data arrives. */
const seed = (path, data) =>
  testEnv.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), path), data),
  );

describe("a pet's medical data", () => {
  // Every record type lives under the same subtree, so one representative
  // path per feature is enough to cover the rule that guards all of them.
  const paths = [
    'users/owner-uid/pets/pet-1/health_records/r1',
    'users/owner-uid/pets/pet-1/weight_records/r1',
    'users/owner-uid/pets/pet-1/toilet_records/r1',
    'users/owner-uid/pets/pet-1/visits/r1',
    'users/owner-uid/pets/pet-1/medications/r1',
    'users/owner-uid/pets/pet-1/prevention_programs/r1',
    'users/owner-uid/pets/pet-1/prevention_records/r1',
    'users/owner-uid/pets/pet-1/consultations/r1',
    'users/owner-uid/pets/pet-1/reports/r1',
  ];

  for (const path of paths) {
    it(`is readable by its owner: ${path.split('/')[4]}`, async () => {
      await seed(path, { note: 'x' });
      await assertSucceeds(getDoc(doc(asOwner(), path)));
    });

    it(`is NOT readable by another signed-in user: ${path.split('/')[4]}`, async () => {
      await seed(path, { note: 'x' });
      await assertFails(getDoc(doc(asOther(), path)));
    });
  }

  it('is not readable by a signed-out client', async () => {
    await seed(paths[0], { note: 'x' });
    await assertFails(getDoc(doc(asAnon(), paths[0])));
  });

  it('cannot be written by another signed-in user', async () => {
    await assertFails(setDoc(doc(asOther(), paths[0]), { note: 'injected' }));
  });

  it('can be written by its owner', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), paths[0]), { note: 'mine' }));
  });
});

describe('the pet profile document itself', () => {
  // Not just its subcollections. This one relies on rules_version '2' making
  // a recursive wildcard match ZERO or more segments -- in v1 it matched one
  // or more, so `pets/{petId}/{document=**}` would not have covered
  // `pets/{petId}`. That is the single most load-bearing assumption in the
  // file, and nothing else here proves it.
  const path = `users/${OWNER}/pets/pet-1`;

  it('is readable and writable by its owner', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), path), { pet_name: 'ポチ' }));
    await assertSucceeds(getDoc(doc(asOwner(), path)));
  });

  it('is not readable by another signed-in user', async () => {
    await seed(path, { pet_name: 'ポチ' });
    await assertFails(getDoc(doc(asOther(), path)));
  });

  it('cannot be written by another signed-in user', async () => {
    await assertFails(setDoc(doc(asOther(), path), { pet_name: 'injected' }));
  });

  it('lists only for its owner', async () => {
    // watchPets() runs a collection query, not a document get.
    await seed(path, { pet_name: 'ポチ' });
    await assertSucceeds(getDocs(collection(asOwner(), `users/${OWNER}/pets`)));
    await assertFails(getDocs(collection(asOther(), `users/${OWNER}/pets`)));
  });
});

describe('the account document', () => {
  const path = `users/${OWNER}`;

  it('is readable and writable by its owner', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), path), { email: 'a@b.c' }));
    await assertSucceeds(getDoc(doc(asOwner(), path)));
  });

  it('is not readable by another signed-in user', async () => {
    await seed(path, { email: 'a@b.c' });
    await assertFails(getDoc(doc(asOther(), path)));
  });

  it("cannot have its active session hijacked by another user", async () => {
    // Writing someone else's active_session_id would sign them out on demand.
    await seed(path, { active_session_id: 'session-1' });
    await assertFails(
      updateDoc(doc(asOther(), path), { active_session_id: 'attacker' }),
    );
  });
});

describe('AI usage counters', () => {
  const path = `users/${OWNER}/usage_counters/current`;

  it('are readable and writable by their owner', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), path), { consultations: 1 }));
  });

  it('are not readable by another signed-in user', async () => {
    await seed(path, { consultations: 1 });
    await assertFails(getDoc(doc(asOther(), path)));
  });
});

describe('cross-user writes to owner-scoped documents', () => {
  // Read isolation is covered above; these pin the write side, which is what
  // an attacker would use to plant or destroy data rather than read it.
  const cases = {
    'usage counter': `users/${OWNER}/usage_counters/current`,
    // Nobody may write these at all now, owner included -- covered in its
    // own suite below; kept here so the cross-user case is explicit too.
    'redemption marker': `users/${OWNER}/redeemed_codes/CODE1`,
    'health record': `users/${OWNER}/pets/pet-1/health_records/r1`,
    'certificate record': `users/${OWNER}/pets/pet-1/prevention_records/r1`,
  };

  for (const [name, path] of Object.entries(cases)) {
    it(`another user cannot create a ${name}`, async () => {
      await assertFails(setDoc(doc(asOther(), path), { planted: true }));
    });
  }
});

describe('campaign codes and redemption markers', () => {
  // Both are written only by the Worker, which uses admin credentials and
  // bypasses rules. Clients get nothing -- a client that can record its own
  // redemption can equally skip recording one, which is why this could not
  // be secured by narrowing the rules instead of closing them.
  const marker = `users/${OWNER}/redeemed_codes/CODE1`;
  const code = 'campaign_codes/CODE1';

  it('a user cannot read their own redemption markers', async () => {
    await seed(marker, { redeemedAt: 1 });
    await assertFails(getDoc(doc(asOwner(), marker)));
  });

  it('a user cannot create a redemption marker', async () => {
    // Otherwise they could forge one for someone else, or skip their own.
    await assertFails(setDoc(doc(asOwner(), marker), { redeemedAt: 1 }));
  });

  it('a user cannot delete a redemption marker', async () => {
    // Deleting one would let the same account redeem a one-per-user code
    // again.
    await seed(marker, { redeemedAt: 1 });
    await assertFails(deleteDoc(doc(asOwner(), marker)));
  });

  it('campaign codes cannot be read by a client', async () => {
    await seed(code, { active: true, maxRedemptions: 10, redemptionCount: 0 });
    await assertFails(getDoc(doc(asOwner(), code)));
  });

  it('campaign codes cannot be listed by a client', async () => {
    await seed(code, { active: true, maxRedemptions: 10, redemptionCount: 0 });
    await assertFails(getDocs(collection(asOwner(), 'campaign_codes')));
  });

  it('a client cannot bump a redemption count', async () => {
    await seed(code, { active: true, maxRedemptions: 10, redemptionCount: 0 });
    await assertFails(updateDoc(doc(asOwner(), code), { redemptionCount: 1 }));
  });

  it('a client cannot mint a code', async () => {
    await assertFails(
      setDoc(doc(asOwner(), 'campaign_codes/FREEMONTH'), {
        active: true,
        maxRedemptions: 1000,
        redemptionCount: 0,
        referrerUid: OWNER,
      }),
    );
  });

  it('a client cannot create even its own referral code', async () => {
    // It is created by POST /billing/referral-code now.
    const own = `campaign_codes/REF-${OWNER.slice(0, 8).toUpperCase()}`;
    await assertFails(
      setDoc(doc(asOwner(), own), {
        active: true,
        maxRedemptions: 1000,
        redemptionCount: 0,
        referrerUid: OWNER,
      }),
    );
  });
});

describe('referral rewards and pending grants', () => {
  // Both are written only by the Worker. A client that could write either
  // could mint itself premium: the counter is the five-reward cap, and a
  // pending grant is a promise of a free month waiting to be redeemed.
  const counter = `users/${OWNER}/rewards/referral`;
  const grant = `users/${OWNER}/pending_grants/g1`;

  it('the owner can read their reward counter', async () => {
    // The app shows "referrals 3/5" from this.
    await seed(counter, { rewardedCount: 3 });
    await assertSucceeds(getDoc(doc(asOwner(), counter)));
  });

  it('the owner cannot write their reward counter', async () => {
    // Otherwise the five-reward cap is whatever the client says it is.
    await seed(counter, { rewardedCount: 3 });
    await assertFails(setDoc(doc(asOwner(), counter), { rewardedCount: 0 }));
  });

  it('another user cannot read the counter', async () => {
    await seed(counter, { rewardedCount: 3 });
    await assertFails(getDoc(doc(asOther(), counter)));
  });

  it('the owner can read their pending grants', async () => {
    await seed(grant, { reason: 'referral', months: 1 });
    await assertSucceeds(getDoc(doc(asOwner(), grant)));
  });

  it('the owner cannot create a pending grant', async () => {
    // A pending grant is a free month waiting to be applied.
    await assertFails(
      setDoc(doc(asOwner(), grant), { reason: 'referral', months: 1 }),
    );
  });

  it('the owner cannot un-apply a pending grant', async () => {
    // Clearing appliedAt would let the same month be claimed again.
    await seed(grant, { reason: 'referral', appliedAt: 'x' });
    await assertFails(deleteDoc(doc(asOwner(), grant)));
    await assertFails(
      updateDoc(doc(asOwner(), grant), { appliedAt: null }),
    );
  });

  it('another user cannot read a pending grant', async () => {
    await seed(grant, { reason: 'referral', months: 1 });
    await assertFails(getDoc(doc(asOther(), grant)));
  });
});

describe('the account deletion sweep', () => {
  // FirestoreAccountDocumentEraser walks the account from the client, so the
  // rules have to permit every step of that walk. A delete the rules refuse
  // is not a silent failure -- but it is a *user-visible* one, mid-way
  // through an irreversible operation, on a screen that has already told the
  // user their data is going away.
  const petId = 'pet-1';

  it('the owner can delete each pet subcollection document', async () => {
    const paths = [
      `users/${OWNER}/pets/${petId}/health_records/r1`,
      `users/${OWNER}/pets/${petId}/weight_records/w1`,
      `users/${OWNER}/pets/${petId}/toilet_records/t1`,
      `users/${OWNER}/pets/${petId}/visits/v1`,
      `users/${OWNER}/pets/${petId}/medications/m1`,
      `users/${OWNER}/pets/${petId}/prevention_programs/p1`,
      `users/${OWNER}/pets/${petId}/prevention_records/pr1`,
      `users/${OWNER}/pets/${petId}/consultations/c1`,
      `users/${OWNER}/pets/${petId}/reports/rep1`,
    ];
    for (const path of paths) {
      await seed(path, { a: 1 });
      await assertSucceeds(deleteDoc(doc(asOwner(), path)));
    }
  });

  it('the owner can enumerate their pets, counters and subcollections', async () => {
    // The sweep is a *list* before it is a delete: it has to read the pet
    // ids to know which subcollections exist. `allow read` covers both get
    // and list, which is what makes this work.
    await seed(`users/${OWNER}/pets/${petId}`, { pet_name: 'Pochi' });
    await seed(`users/${OWNER}/pets/${petId}/health_records/r1`, { a: 1 });
    await seed(`users/${OWNER}/usage_counters/2026-08`, { count: 3 });

    await assertSucceeds(getDocs(collection(asOwner(), `users/${OWNER}/pets`)));
    await assertSucceeds(
      getDocs(
        collection(asOwner(), `users/${OWNER}/pets/${petId}/health_records`),
      ),
    );
    await assertSucceeds(
      getDocs(collection(asOwner(), `users/${OWNER}/usage_counters`)),
    );
  });

  it('the owner can delete their pet, counters and account document', async () => {
    await seed(`users/${OWNER}/pets/${petId}`, { pet_name: 'Pochi' });
    await seed(`users/${OWNER}/usage_counters/2026-08`, { count: 3 });
    await seed(`users/${OWNER}`, { email: 'a@b.test' });

    await assertSucceeds(
      deleteDoc(doc(asOwner(), `users/${OWNER}/pets/${petId}`)),
    );
    await assertSucceeds(
      deleteDoc(doc(asOwner(), `users/${OWNER}/usage_counters/2026-08`)),
    );
    await assertSucceeds(deleteDoc(doc(asOwner(), `users/${OWNER}`)));
  });

  it('another user cannot delete this account', async () => {
    // The obvious catastrophe if ownership were ever keyed off anything but
    // the uid in the path.
    await seed(`users/${OWNER}`, { email: 'a@b.test' });
    await seed(`users/${OWNER}/pets/${petId}/health_records/r1`, { a: 1 });

    await assertFails(deleteDoc(doc(asOther(), `users/${OWNER}`)));
    await assertFails(
      deleteDoc(
        doc(asOther(), `users/${OWNER}/pets/${petId}/health_records/r1`),
      ),
    );
  });

  it('nobody can delete the server-owned collections from a client', async () => {
    // Which is exactly why account deletion has to call the Worker for
    // these -- see functions/src/routes/deleteAccountServerData.ts. A rule
    // relaxed to let the client sweep them would also let it erase its own
    // redemption marker and redeem the same code twice.
    await seed(`users/${OWNER}/redeemed_codes/SUMMER`, { at: 1 });
    await seed(`users/${OWNER}/rewards/referral_counter`, { count: 2 });
    await seed(`users/${OWNER}/pending_grants/g1`, { months: 1 });

    await assertFails(
      deleteDoc(doc(asOwner(), `users/${OWNER}/redeemed_codes/SUMMER`)),
    );
    await assertFails(
      deleteDoc(doc(asOwner(), `users/${OWNER}/rewards/referral_counter`)),
    );
    await assertFails(
      deleteDoc(doc(asOwner(), `users/${OWNER}/pending_grants/g1`)),
    );
  });
});

describe('in-app announcements', () => {
  const notice = 'announcements/support-away';

  it('are readable by a signed-OUT client', async () => {
    // The load-bearing one. The notice people most need is the one telling
    // them why they cannot sign in, so this collection is deliberately the
    // single readable-by-anyone path in the database.
    await seed(notice, { title_ja: '障害のお知らせ', important: true });
    await assertSucceeds(getDoc(doc(asAnon(), notice)));
  });

  it('are readable by a signed-in client', async () => {
    await seed(notice, { title_ja: 'サポート休止のお知らせ' });
    await assertSucceeds(getDoc(doc(asOwner(), notice)));
  });

  it('can be listed, which is how the banner finds the newest', async () => {
    await seed(notice, { title_ja: 'お知らせ' });
    await assertSucceeds(getDocs(collection(asAnon(), 'announcements')));
  });

  it('cannot be written by anyone, signed in or not', async () => {
    // An app that can post its own notices is an app whose notices cannot be
    // trusted. These are authored in the Firebase console only.
    await assertFails(setDoc(doc(asOwner(), notice), { title_ja: 'fake' }));
    await assertFails(setDoc(doc(asAnon(), notice), { title_ja: 'fake' }));
  });

  it('cannot be edited or deleted by a client', async () => {
    await seed(notice, { title_ja: 'お知らせ' });
    await assertFails(updateDoc(doc(asOwner(), notice), { title_ja: '改ざん' }));
    await assertFails(deleteDoc(doc(asOwner(), notice)));
  });
});

describe('paths the app does not use', () => {
  it('are denied by default rather than silently open', async () => {
    // There is no catch-all match, so a collection someone adds later fails
    // closed until it is added to the rules deliberately.
    await assertFails(setDoc(doc(asOwner(), 'anything_else/x'), { a: 1 }));
    await assertFails(getDoc(doc(asOwner(), 'anything_else/x')));
  });
});
