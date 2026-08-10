import 'emulator_web_support_stub.dart'
    if (dart.library.js_interop) 'emulator_web_support_web.dart';

/// Base URL of the serverless backend (the Cloudflare Worker under
/// `functions/`), set at build time with
/// `--dart-define=AI_BACKEND_BASE_URL=https://...`. Empty in local dev.
const String configuredBackendBaseUrl = String.fromEnvironment(
  'AI_BACKEND_BASE_URL',
);

/// Where to reach `wrangler dev` when no base URL was configured.
///
/// Follows the host that served the page on web, for the same reason the
/// Firebase emulators do (see `emulator_config.dart`): a phone opening the
/// app at `http://192.168.x.x:5000` has to reach the Worker on the dev
/// machine, and a hardcoded `localhost` would point it at the phone itself.
String defaultLocalBackendBaseUrl() => 'http://${localDevHost()}:8787';
