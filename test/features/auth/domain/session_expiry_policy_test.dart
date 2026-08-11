import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/auth/domain/session_expiry_policy.dart';

/// PM request: "ログインしたままはセキュリティ上よくないので、前回ログインから
/// １日経過していたら自動ログアウトとしたい".
///
/// The boundary is the whole feature -- an off-by-one here either logs people
/// out early (support complaints) or never (the window silently does
/// nothing, which looks identical to working).
void main() {
  const policy = SessionExpiryPolicy();
  final now = DateTime(2026, 8, 11, 12);

  test('a session authenticated just now is live', () {
    expect(policy.hasExpired(lastAuthenticatedAt: now, now: now), isFalse);
  });

  test('23 hours is still inside the window', () {
    expect(
      policy.hasExpired(
        lastAuthenticatedAt: now.subtract(const Duration(hours: 23)),
        now: now,
      ),
      isFalse,
    );
  });

  test('exactly 24 hours has expired', () {
    // The boundary is inclusive: "1日経過していたら" reads as at-or-past.
    expect(
      policy.hasExpired(
        lastAuthenticatedAt: now.subtract(const Duration(hours: 24)),
        now: now,
      ),
      isTrue,
    );
  });

  test('a week has expired', () {
    expect(
      policy.hasExpired(
        lastAuthenticatedAt: now.subtract(const Duration(days: 7)),
        now: now,
      ),
      isTrue,
    );
  });

  test('no recorded authentication counts as expired', () {
    // Upgrading from a build before this existed, or cleared storage: the
    // session's age is unknown, and honouring an unknown-age session is the
    // thing being prevented.
    expect(policy.hasExpired(lastAuthenticatedAt: null, now: now), isTrue);
  });

  test('a timestamp in the future does not lock the user out', () {
    // The device clock moved backwards. Signing in again cannot fix that, so
    // treating it as expired would loop them at the sign-in screen.
    expect(
      policy.hasExpired(
        lastAuthenticatedAt: now.add(const Duration(days: 2)),
        now: now,
      ),
      isFalse,
    );
  });

  test('the window length is configurable', () {
    const shortPolicy = SessionExpiryPolicy(maxAge: Duration(hours: 1));
    expect(
      shortPolicy.hasExpired(
        lastAuthenticatedAt: now.subtract(const Duration(minutes: 90)),
        now: now,
      ),
      isTrue,
    );
  });
}
