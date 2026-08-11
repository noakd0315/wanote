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

describe('paths the app does not use', () => {
  it('are denied by default rather than silently open', async () => {
    // There is no catch-all match, so a collection someone adds later fails
    // closed until it is added to the rules deliberately.
    await assertFails(setDoc(doc(asOwner(), 'anything_else/x'), { a: 1 }));
    await assertFails(getDoc(doc(asOwner(), 'anything_else/x')));
  });
});
