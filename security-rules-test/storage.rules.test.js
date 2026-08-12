import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteObject,
  getBytes,
  list,
  ref,
  uploadBytes,
} from 'firebase/storage';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

// Access-control tests for storage.rules, run against the Storage emulator
// that docker-compose publishes on 9199.
//
// Storage holds the most sensitive artifacts in the app: photographs of
// vaccination certificates and vet paperwork. A broken *read* rule here fails
// silently -- the app keeps working perfectly for the owner while the files
// are readable by anyone -- so it cannot be caught by using the app.
//
// The rules also use constructs the Firestore ones don't: request.resource
// size and contentType checks, and a deliberate split of `create, update`
// from `delete` (request.resource is null on a delete, so folding them
// together makes deleting impossible). Those are exactly the subtleties that
// break quietly.
//
// Requires the emulators to be up: `docker compose up -d`.

const OWNER = 'owner-uid';
const OTHER = 'intruder-uid';

/** A certificate scan lives here -- the most sensitive path in the bucket. */
const CERT = `users/${OWNER}/pets/pet-1/prevention_certificates/rec-1`;

const JPEG = { contentType: 'image/jpeg' };
const bytes = (n = 8) => new Uint8Array(n).fill(1);

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    // Separate from the app's `demo-wanote`: clearStorage() wipes the project
    // it is given, and pointing these at the app's project would delete the
    // local development uploads on every run.
    projectId: 'demo-wanote-rules-test',
    storage: {
      rules: readFileSync('../storage.rules', 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

const asOwner = () => testEnv.authenticatedContext(OWNER).storage();
const asOther = () => testEnv.authenticatedContext(OTHER).storage();
const asAnon = () => testEnv.unauthenticatedContext().storage();

/** Puts a file in place with the rules switched off. */
const seed = (path) =>
  testEnv.withSecurityRulesDisabled((ctx) =>
    uploadBytes(ref(ctx.storage(), path), bytes(), JPEG),
  );

describe('a certificate scan', () => {
  it('is readable by its owner', async () => {
    await seed(CERT);
    await assertSucceeds(getBytes(ref(asOwner(), CERT)));
  });

  it('is NOT readable by another signed-in user', async () => {
    await seed(CERT);
    await assertFails(getBytes(ref(asOther(), CERT)));
  });

  it('is NOT readable by a signed-out client', async () => {
    await seed(CERT);
    await assertFails(getBytes(ref(asAnon(), CERT)));
  });

  it('cannot be overwritten by another signed-in user', async () => {
    await seed(CERT);
    await assertFails(uploadBytes(ref(asOther(), CERT), bytes(), JPEG));
  });

  it('cannot be deleted by another signed-in user', async () => {
    await seed(CERT);
    await assertFails(deleteObject(ref(asOther(), CERT)));
  });

  it('can be uploaded, replaced and deleted by its owner', async () => {
    // Delete is granted separately from create/update because
    // request.resource is null on a delete. If that split is ever collapsed,
    // this is what fails.
    await assertSucceeds(uploadBytes(ref(asOwner(), CERT), bytes(), JPEG));
    await assertSucceeds(uploadBytes(ref(asOwner(), CERT), bytes(16), JPEG));
    await assertSucceeds(deleteObject(ref(asOwner(), CERT)));
  });
});

describe('the other upload paths', () => {
  const paths = {
    'pet photo': `users/${OWNER}/pets/pet-1/icon.jpg`,
    'health record photo': `users/${OWNER}/pets/pet-1/health_records/r1/0.jpg`,
    'toilet record photo': `users/${OWNER}/pets/pet-1/toilet_records/t1.jpg`,
  };

  for (const [name, path] of Object.entries(paths)) {
    it(`${name}: owner can write, another user cannot read`, async () => {
      await assertSucceeds(uploadBytes(ref(asOwner(), path), bytes(), JPEG));
      await assertFails(getBytes(ref(asOther(), path)));
    });
  }
});

describe('upload constraints', () => {
  it('reject a file over the 5MB cap', async () => {
    // Every photo the app uploads is compressed to well under a megabyte, so
    // this is a backstop against something bypassing the app.
    const tooBig = new Uint8Array(5 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(asOwner(), CERT), tooBig, JPEG));
  });

  it('reject a non-image content type', async () => {
    // Worth pinning explicitly: certificates are described as scans, and
    // CertificateStorageService.upload takes an arbitrary contentType. Today
    // every call site passes image/jpeg, so a PDF certificate would be
    // rejected here -- if PDFs are ever allowed, this rule has to change
    // first and this test is what will say so.
    await assertFails(
      uploadBytes(ref(asOwner(), CERT), bytes(), {
        contentType: 'application/pdf',
      }),
    );
  });

  it('accept an ordinary photo', async () => {
    await assertSucceeds(uploadBytes(ref(asOwner(), CERT), bytes(1024), JPEG));
  });
});

describe('the account deletion sweep', () => {
  // StorageAccountFileEraser walks `users/{uid}` with list() and deletes
  // what it finds. Listing is a distinct permission from reading an object,
  // and it is evaluated against the *prefix* rather than a file -- so
  // "the owner can download their certificate" says nothing about whether
  // the owner can enumerate the folder it sits in. Without list, account
  // deletion cannot find a single file to remove.
  it('the owner can list their own folder and its subfolders', async () => {
    await seed(`users/${OWNER}/pets/pet-1/icon.jpg`);
    await seed(CERT);

    const root = await assertSucceeds(list(ref(asOwner(), `users/${OWNER}`)));
    expect(root.prefixes.map((p) => p.name)).toContain('pets');

    const pet = await assertSucceeds(
      list(ref(asOwner(), `users/${OWNER}/pets/pet-1`)),
    );
    expect(pet.items.map((i) => i.name)).toContain('icon.jpg');
  });

  it('another signed-in user cannot list it', async () => {
    // Listing leaks structure even when the files themselves stay closed:
    // pet ids, how many records exist, which certificates were uploaded.
    await seed(CERT);
    await assertFails(list(ref(asOther(), `users/${OWNER}`)));
  });

  it('the owner can delete every file the sweep will find', async () => {
    const paths = [
      `users/${OWNER}/pets/pet-1/profile.jpg`,
      `users/${OWNER}/pets/pet-1/profile_icon.jpg`,
      `users/${OWNER}/pets/pet-1/health_records/r1/0.jpg`,
      `users/${OWNER}/pets/pet-1/toilet_records/t1.jpg`,
      CERT,
    ];
    for (const path of paths) {
      await seed(path);
      await assertSucceeds(deleteObject(ref(asOwner(), path)));
    }
  });
});

describe('paths outside the users tree', () => {
  it('are not writable, even by a signed-in user', async () => {
    // There is no other match block, so anything outside users/{uid} fails
    // closed rather than becoming free file hosting.
    await assertFails(
      uploadBytes(ref(asOwner(), 'public/anything.jpg'), bytes(), JPEG),
    );
  });

  it('are not readable', async () => {
    await seed('public/anything.jpg');
    await assertFails(getBytes(ref(asOwner(), 'public/anything.jpg')));
  });
});
