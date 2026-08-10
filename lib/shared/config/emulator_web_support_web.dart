/// The web build cannot attach the Auth emulator the normal way, so it
/// rewrites the SDK's outgoing requests instead. This file is only ever
/// reached when `USE_FIREBASE_EMULATOR=true`; the production build compiles
/// none of it.
///
/// ## Why not `FirebaseAuth.useAuthEmulator()`
///
/// On web that call is a silent no-op. `firebase_core_web` runs
/// firebase_auth_web's `ensurePluginInitialized` *inside*
/// `Firebase.initializeApp()`, and that registers an auth state observer,
/// which initializes the JS SDK's Auth. From then on the JS SDK's
/// `connectAuthEmulator()` throws `auth/emulator-config-failed` -- and
/// firebase_auth_web catches exactly that code and ignores it, treating it as
/// the harmless hot-reload case. The call returns normally while every request
/// still goes to the real `identitytoolkit.googleapis.com`, which answers
/// "API key not valid" for our placeholder demo key.
///
/// firebase_auth_web has one path that does attach the emulator in time: it
/// re-applies an origin found in session storage during
/// `ensurePluginInitialized`. But that path is guarded by
/// `location.hostname == 'localhost' && kDebugMode`, so it is unavailable in
/// exactly the two cases we need:
///
///   * `flutter build web` (the `:5000` static build) -- not debug mode;
///   * opening the app from a phone on the LAN -- hostname is an IP.
///
/// ## What this does instead
///
/// Wraps `window.fetch` so requests to the two Google auth hosts are sent to
/// the emulator, using the same URL layout the emulator already expects and
/// that `connectAuthEmulator` would itself have produced:
///
///   `https://identitytoolkit.googleapis.com/v1/X`
///     -> `http://<emulator>:9099/identitytoolkit.googleapis.com/v1/X`
///
/// The JS SDK builds these targets as plain strings and hands them to
/// `fetch`, so intercepting there covers sign-in, sign-up, and token refresh
/// without depending on any plugin internals -- it works in release builds and
/// from any hostname.
///
/// The trade-off is that this is a shim, not a supported API: the JS SDK does
/// not know it is talking to an emulator, so its "Running in emulator mode"
/// banner does not appear and its emulator-only relaxations (e.g. skipping
/// reCAPTCHA for phone auth, which this app does not use) do not apply.
library;

import 'dart:convert';

import 'package:web/web.dart' as web;

/// Local dev services live on whatever host served the page, so opening the
/// app from a phone at `http://192.168.x.x:5000` reaches the emulators (and
/// `wrangler dev`) on that machine rather than on the phone itself. The
/// matching `--dart-define` still wins when set -- the Android emulator needs
/// `EMULATOR_HOST=10.0.2.2`.
String localDevHost() {
  final hostname = web.window.location.hostname;
  return hostname.isEmpty ? 'localhost' : hostname;
}

/// Sends the Firebase Auth REST calls to the emulator at [origin]
/// (e.g. `http://192.168.1.5:9099`). Must run before
/// `Firebase.initializeApp()`, which already refreshes a persisted session.
///
/// Injected as a `<script>` rather than written with `dart:js_interop`
/// because the wrapper has to hand `fetch`'s arguments straight back to the
/// browser untouched; round-tripping `Request`/`RequestInit` through Dart
/// would risk dropping fields on request shapes we never see.
void routeAuthRequestsToEmulator(String origin) {
  // Clear firebase_auth_web's own emulator-restore key. On localhost in debug
  // it would otherwise also attach the emulator, at its own hardcoded origin,
  // and two mechanisms disagreeing about the host is worse than one.
  web.window.sessionStorage.removeItem('[DEFAULT]-firebaseEmulatorOrigin');

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.text =
      '''
(function () {
  var origin = ${jsonEncode(origin)};
  var prefixes = [
    'https://identitytoolkit.googleapis.com/',
    'https://securetoken.googleapis.com/'
  ];
  var nativeFetch = window.fetch.bind(window);
  window.fetch = function (input, init) {
    if (typeof input === 'string') {
      for (var i = 0; i < prefixes.length; i++) {
        if (input.indexOf(prefixes[i]) === 0) {
          // Drop the scheme only: the emulator keys its routes on the
          // original host, e.g. /identitytoolkit.googleapis.com/v1/...
          input = origin + '/' + input.slice('https://'.length);
          break;
        }
      }
    }
    return nativeFetch(input, init);
  };
})();
''';
  web.document.head!.appendChild(script);
}
