/// How long a session may go without the user proving who they are again.
///
/// Firebase's persisted session never expires on its own: the SDK keeps
/// renewing the ID token from a refresh token that has no time limit, and
/// nothing in the app asked again. Someone who signed in once stayed signed
/// in until they deleted the app. For a phone that holds a pet's medical
/// records, leaving that window open forever is the wrong default (PM
/// request: "ログインしたままはセキュリティ上よくないので、前回ログインから
/// １日経過していたら自動ログアウトとしたい").
///
/// Pure and framework-free so the boundary can be tested without a clock, a
/// widget tree or Firebase -- see
/// test/features/auth/domain/session_expiry_policy_test.dart.
class SessionExpiryPolicy {
  const SessionExpiryPolicy({this.maxAge = const Duration(days: 1)});

  /// Time allowed between authentications before one is required again.
  final Duration maxAge;

  /// Whether the session needs re-authenticating.
  ///
  /// [lastAuthenticatedAt] is when the user last *proved* who they are --
  /// an explicit sign-in, or a successful biometric unlock. Resuming a
  /// persisted session deliberately does not count: if merely opening the
  /// app pushed the deadline back, a phone that gets opened daily would
  /// never re-authenticate at all, which is the situation this exists to
  /// end.
  ///
  /// A null [lastAuthenticatedAt] means the app has no record of the last
  /// authentication -- an upgrade from a build before this existed, or
  /// cleared storage. Treated as expired: asking once more is a small cost,
  /// and the alternative is honouring a session of unknown age.
  bool hasExpired({
    required DateTime? lastAuthenticatedAt,
    required DateTime now,
  }) {
    if (lastAuthenticatedAt == null) return true;
    // A timestamp in the future means the device clock moved backwards
    // since it was written. Not expired: the user cannot fix a clock skew by
    // signing in again, and locking them out over it would be worse than
    // the extra hours of session it grants.
    if (lastAuthenticatedAt.isAfter(now)) return false;
    return now.difference(lastAuthenticatedAt) >= maxAge;
  }
}
