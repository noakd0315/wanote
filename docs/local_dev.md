# Local dev environment (Docker, no cloud accounts required)

This gets the app to a click-through-able state on a fresh machine with
**zero** real Firebase, RevenueCat, or Anthropic accounts. Requires only
Docker + Docker Compose and, to run the Flutter app itself, a Flutter SDK and
(for the fastest path) Chrome.

## 1. Bring up the backend

From the repo root:

```
docker compose up
```

This builds and starts two containers:

- **`firebase-emulators`** — the Firebase Local Emulator Suite (Auth on
  `9099`, Firestore on host `8081` [container-internal `8080`; remapped
  because host `8080` was already taken by an unrelated container on the
  dev machine], Storage on `9199`, Emulator UI on `4000`),
  running against the fake project id `demo-wanote` (see `firebase.json` /
  `.firebaserc`). Firebase treats any `demo-*` project id as a local-only
  fake project — no real GCP project, billing, or `firebase login` needed.
- **`functions-dev`** — the Cloudflare Workers backend (`functions/`) via
  `wrangler dev --ip 0.0.0.0`, on `8787`. This also runs entirely locally;
  no Cloudflare account or `wrangler login` needed for local dev (only for
  `wrangler deploy`, which this setup never does).

Add `-d` to run in the background; `docker compose down` to stop everything.

### Optional: a real Anthropic API key

By default, every AI-backed endpoint (OCR extraction, AI consultation, AI
report) returns a clearly-labeled **mock response** — text prefixed/suffixed
with `[MOCK RESPONSE — set ANTHROPIC_API_KEY for a real answer]` — instead of
calling the real Claude API. This is implemented in
`functions/src/lib/anthropicClient.ts`'s `callClaude()` and logs a warning
server-side whenever it fires, so it's never mistaken for a real answer, and
the full app flow (OCR review screen, AI consultation, AI report) can be
smoke-tested with zero API cost.

To get real AI responses instead:

```
cp functions/.dev.vars.example functions/.dev.vars
# edit functions/.dev.vars and fill in a real ANTHROPIC_API_KEY
docker compose restart functions-dev
```

`functions/.dev.vars` is gitignored — never commit it.

## 2. Run the Flutter app against it

The fastest path is Flutter web (needs Chrome, which is installed on this
machine):

```
flutter run -d chrome \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=AI_BACKEND_BASE_URL=http://localhost:8787
```

`USE_FIREBASE_EMULATOR=true` makes `lib/shared/config/emulator_config.dart`
point the Firebase Auth/Firestore/Storage SDKs at `localhost:9099` /
`localhost:8081` / `localhost:9199` (the same ports docker-compose publishes),
using the placeholder `demoFirebaseOptions` in
`lib/shared/config/firebase_options_demo.dart` (`projectId: 'demo-wanote'`,
matching `.firebaserc`).

Running on the Android emulator instead of web? Add
`--dart-define=EMULATOR_HOST=10.0.2.2` (the Android emulator's alias for the
host machine's `localhost`) and use `http://10.0.2.2:8787` for
`AI_BACKEND_BASE_URL`.

## 3. What this setup CAN and CANNOT verify

**CAN:**

- Email/password sign-up and sign-in (Auth emulator supports this fully).
- Firestore-backed daily records and medical records (weight, toilet log,
  vaccinations, medication, etc.) — reads/writes go to the Firestore
  emulator, governed by the wide-open dev-only `firestore.rules` in this
  repo (see that file's header comment — **not** what should ever be
  deployed to production).
- AI consultation / AI report / certificate OCR flows, against either the
  real Claude API (if you supplied `ANTHROPIC_API_KEY`) or the mock
  responses described above.
- General navigation and UI across the app.

**CANNOT / needs something else:**

- **Google/Apple OAuth sign-in buttons** — the Auth emulator does not perform
  real OAuth verification, so "Sign in with Google/Apple" will not work
  against it. Only email/password auth is testable here.
- **Native biometric auth** (Face ID / fingerprint unlock) — needs a real
  device or Android emulator with a virtual biometric sensor, not something
  Firebase emulators or `flutter run -d chrome` can provide. The Android SDK
  is already installed on this machine; creating a real AVD (Android Virtual
  Device) is the right path for specifically testing this flow.
- **Google Mobile Ads** — no web plugin support; needs a mobile build
  (Android/iOS) to test.
- **RevenueCat real purchases** — needs a Play Store / App Store sandbox
  tester account; cannot be exercised through this local setup at all.
- **Anything iOS-specific** — needs a Mac (Xcode toolchain), not available on
  this Windows machine.

## 4. Seeding a test user / pet

### Option A: Emulator UI (easiest)

Open <http://localhost:4000> once the containers are up, go to the
**Authentication** tab, and add a user manually (email + password). Then
either create pet/record documents by hand in the **Firestore** tab, or just
sign up/sign in through the running Flutter app and use its normal UI to add
a pet — it's simpler to let the app write its own Firestore documents so you
don't have to guess the schema.

### Option B: REST API (scriptable)

The Auth emulator exposes the same REST API as real Firebase Auth. Create a
test account with:

```
curl -X POST \
  "http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=any-string-works" \
  -H "Content-Type: application/json" \
  -d '{"email":"pm-test@example.com","password":"testpass123","returnSecureToken":true}'
```

(The `key` query param is required by the API shape but its value is not
checked by the emulator — any non-empty string works.) The response includes
an `idToken` you can use directly as a `Authorization: Bearer <idToken>`
header against `functions-dev` (`http://localhost:8787/ai/consultation`,
etc.) to test the backend independent of the Flutter app.

## 5. Verifying the stack is up

```
docker compose ps
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4000        # Emulator UI -> 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8787/ai/consultation  # Workers dev server -> 401 (no auth header) — this confirms it's up and routing, not connection-refused
```

## Notes / known limitations of this setup

- **Rate-limiter KV binding**: `functions/wrangler.toml` declares a
  `RATE_LIMIT_KV` binding used by `functions/src/lib/rateLimiter.ts`. In
  local `wrangler dev` (what `functions-dev` runs — no `--remote` flag),
  this is simulated entirely in-process; the placeholder id in
  `wrangler.toml` does not need to correspond to a real, provisioned
  Cloudflare KV namespace for local dev. It does need to be replaced with a
  real namespace id (`wrangler kv namespace create RATE_LIMIT_KV`) before
  `wrangler deploy` to a real Cloudflare account.
- **Auth emulator tokens are unsigned**: the Firebase Auth Emulator issues
  unsigned ID tokens by design (documented Firebase behavior). Because of
  this, `functions/src/lib/verifyFirebaseToken.ts` has a local-dev-only
  branch that skips signature verification (still checking issuer/audience/
  subject claims) whenever `env.FIREBASE_AUTH_EMULATOR_HOST` is set — see
  `functions/.dev.vars.example`. This mirrors what the real Firebase Admin
  SDK itself does when that same env var is set, so it's standard practice,
  not a security shortcut specific to this repo. This flag must stay unset
  in any real deployment (it is never present in `wrangler secret` config),
  so production always performs full signature verification.
