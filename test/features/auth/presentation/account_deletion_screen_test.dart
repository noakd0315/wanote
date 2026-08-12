import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wanote/features/auth/presentation/auth_controller.dart';
import 'package:wanote/features/auth/presentation/screens/account_deletion_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/models/app_user.dart';
import 'package:wanote/shared/models/auth_provider_type.dart';

class MockAuthController extends Mock implements AuthController {}

/// The screen's job is to make an irreversible action hard to do by
/// accident, and to say the things Apple and Google require be said before
/// it happens. Both are behaviour worth pinning: a layout change that drops
/// the confirmation dialog or the subscription notice looks harmless in a
/// diff.
void main() {
  late MockAuthController controller;

  setUp(() {
    controller = MockAuthController();
    when(
      () => controller.deleteAccount(password: any(named: 'password')),
    ).thenAnswer((_) async {});
  });

  void signedInAs(AuthProviderType provider) {
    when(() => controller.currentUser).thenReturn(
      AppUser(
        uid: 'uid-1',
        email: 'owner@example.com',
        authProvider: provider,
        biometricEnabled: false,
      ),
    );
  }

  /// Pushes the screen onto a route below it, the way settings does. It
  /// matters: on success the screen pops itself, and a screen that *is* the
  /// first route would instead sit there spinning forever.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountDeletionScreen(),
                  ),
                ),
                child: const Text('open settings entry'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open settings entry'));
    await tester.pumpAndSettle();
  }

  /// The button sits below a long warning panel, so in the test viewport it
  /// starts off-screen.
  Future<void> tapDeleteButton(WidgetTester tester) async {
    final button = find.text('Delete my account');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('warns that the store subscription keeps billing', (
    tester,
  ) async {
    // Subscriptions live with the App Store / Google Play, not with this
    // app: deleting the account here does not stop the charges. Both stores
    // require the user be told, and someone who wasn't would keep paying
    // for an account that no longer exists.
    signedInAs(AuthProviderType.email);
    await pumpScreen(tester);

    expect(
      find.textContaining('subscription is not cancelled'),
      findsOneWidget,
    );
  });

  testWidgets('lists what will be destroyed', (tester) async {
    signedInAs(AuthProviderType.email);
    await pumpScreen(tester);

    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(find.textContaining('pet profile'), findsOneWidget);
    expect(find.textContaining('photo and certificate scan'), findsOneWidget);
  });

  testWidgets('the delete button alone deletes nothing', (tester) async {
    signedInAs(AuthProviderType.email);
    await pumpScreen(tester);

    await tapDeleteButton(tester);

    verifyNever(
      () => controller.deleteAccount(password: any(named: 'password')),
    );
    expect(find.text('Delete your account?'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    signedInAs(AuthProviderType.email);
    await pumpScreen(tester);

    await tapDeleteButton(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => controller.deleteAccount(password: any(named: 'password')),
    );
  });

  testWidgets('confirming passes the typed password through', (tester) async {
    signedInAs(AuthProviderType.email);
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tapDeleteButton(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => controller.deleteAccount(password: 'hunter2')).called(1);
    // The account is gone, so the screen has no reason to stay up.
    expect(find.byType(AccountDeletionScreen), findsNothing);
  });

  testWidgets('a Google account is not asked for a password', (tester) async {
    // There is no app password to ask for; the controller redoes the
    // provider sign-in instead.
    signedInAs(AuthProviderType.google);
    await pumpScreen(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('sign in again'), findsOneWidget);
  });

  testWidgets('shows a message when deletion fails, and stays put', (
    tester,
  ) async {
    signedInAs(AuthProviderType.email);
    when(
      () => controller.deleteAccount(password: any(named: 'password')),
    ).thenThrow(Exception('backend down'));
    await pumpScreen(tester);

    await tapDeleteButton(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Deletion failed'), findsOneWidget);
    // Retrying is the documented recovery, so the button has to come back.
    expect(find.text('Delete my account'), findsOneWidget);
  });
}
