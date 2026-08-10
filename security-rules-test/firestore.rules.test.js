import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, updateDoc } from 'firebase/firestore';
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

describe('campaign-code redemption markers', () => {
  const path = `users/${OWNER}/redeemed_codes/CODE1`;

  it('can be created by their owner', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), path), { redeemedAt: 1 }));
  });

  it('cannot be deleted, even by their owner', async () => {
    // Deleting the marker would let the same account redeem a one-per-user
    // code again.
    await seed(path, { redeemedAt: 1 });
    await assertFails(deleteDoc(doc(asOwner(), path)));
  });

  it('cannot be overwritten, even by their owner', async () => {
    await seed(path, { redeemedAt: 1 });
    await assertFails(setDoc(doc(asOwner(), path), { redeemedAt: 2 }));
  });

  it("are not visible to another user", async () => {
    await seed(path, { redeemedAt: 1 });
    await assertFails(getDoc(doc(asOther(), path)));
  });
});

describe('campaign codes', () => {
  const path = 'campaign_codes/CODE1';
  const code = { active: true, maxRedemptions: 10, redemptionCount: 0 };

  it('are readable by any signed-in user', async () => {
    await seed(path, code);
    await assertSucceeds(getDoc(doc(asOwner(), path)));
  });

  it('are not readable by a signed-out client', async () => {
    await seed(path, code);
    await assertFails(getDoc(doc(asAnon(), path)));
  });

  it('accept a redemption count incremented by exactly one', async () => {
    await seed(path, code);
    await assertSucceeds(
      updateDoc(doc(asOwner(), path), { redemptionCount: 1 }),
    );
  });

  it('reject a redemption count moved by anything else', async () => {
    // Decrementing would hand out unlimited redemptions of a capped code.
    await seed(path, { ...code, redemptionCount: 5 });
    await assertFails(updateDoc(doc(asOwner(), path), { redemptionCount: 4 }));
    await assertFails(updateDoc(doc(asOwner(), path), { redemptionCount: 99 }));
  });

  it('reject edits to any other field', async () => {
    // Raising maxRedemptions or reactivating a spent code from the client.
    await seed(path, code);
    await assertFails(
      updateDoc(doc(asOwner(), path), { maxRedemptions: 1000000 }),
    );
    await assertFails(updateDoc(doc(asOwner(), path), { active: true }));
  });

  it('cannot be created or deleted from a client', async () => {
    await assertFails(setDoc(doc(asOwner(), 'campaign_codes/NEW'), code));
    await seed(path, code);
    await assertFails(deleteDoc(doc(asOwner(), path)));
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
