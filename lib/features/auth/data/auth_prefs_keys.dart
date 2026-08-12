/// Every SharedPreferences key the auth feature writes, in one place.
///
/// They were previously spread across AuthController and SignUpScreen as
/// private constants, which was fine until account deletion needed to answer
/// "what does this account leave on this device?" -- a question no single
/// file could answer. [forAccount] is that answer, and it only stays correct
/// if new keys are added here rather than inlined at their call site.
class AuthPrefsKeys {
  const AuthPrefsKeys._();

  /// Which pet the app should reopen on. Not per-uid (it predates
  /// multi-account use of one device) but still account-specific data, so
  /// account deletion clears it.
  static const lastActivePetId = 'auth.last_active_pet_id';

  /// Prefix for this device's copy of the account's claimed session id.
  /// Keyed by uid so switching accounts on one device doesn't confuse one
  /// account's session for another's.
  static const localSessionIdPrefix = 'auth.local_session_id.';

  /// Prefix for when this device last saw the user prove who they are.
  /// Per-uid for the same reason. See SessionExpiryPolicy.
  static const lastAuthenticatedAtPrefix = 'auth.last_authenticated_at.';

  /// Referral code typed at sign-up, stashed until the app shell is ready to
  /// redeem it (see lib/app/home_shell.dart).
  static const pendingReferralCode = 'auth.pending_referral_code';

  /// Last-used email, remembered so returning users don't have to retype it.
  /// Email only -- see SignUpScreen for why the password is never persisted.
  static const rememberedEmail = 'auth.remembered_email';

  /// Everything account deletion has to remove from this device.
  ///
  /// Deleting the account server-side leaves these behind otherwise, and a
  /// stale `rememberedEmail` in particular means the sign-in screen keeps
  /// offering a deleted account's address.
  static List<String> forAccount(String uid) => [
    lastActivePetId,
    '$localSessionIdPrefix$uid',
    '$lastAuthenticatedAtPrefix$uid',
    pendingReferralCode,
    rememberedEmail,
  ];
}
