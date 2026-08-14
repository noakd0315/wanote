import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/app_messenger.dart';
import '../../../../shared/models/auth_provider_type.dart';
import '../auth_controller.dart';

/// Permanent account deletion (spec gap; App Store Review Guideline
/// 5.1.1(v) requires an app that creates accounts to delete them in-app,
/// and Google Play's data deletion policy asks for the same).
///
/// Three things this screen owes the user before it will do anything:
/// a plain list of what disappears, the warning that their store
/// subscription keeps billing regardless, and a reauthentication step -- an
/// unattended phone should not be enough to erase someone's records.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<AuthController>();
    final isEmailAccount =
        controller.currentUser?.authProvider == AuthProviderType.email;

    return PopScope(
      // Deletion is a sequence of independent steps against Firestore,
      // Storage, the Worker and Firebase Auth. Leaving part-way doesn't
      // corrupt anything (every step is idempotent and the identity goes
      // last), but it does leave the account half-erased until the user
      // comes back and retries -- so don't make it easy to walk away.
      canPop: !_isDeleting,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.deleteAccountMenuTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WarningCard(l10n: l10n),
            const SizedBox(height: 16),
            _SubscriptionNoticeCard(l10n: l10n),
            const SizedBox(height: 24),
            if (isEmailAccount)
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_isDeleting,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.deleteAccountPasswordFieldLabel,
                  helperText: l10n.deleteAccountPasswordHelperText,
                  border: const OutlineInputBorder(),
                ),
              )
            else
              Text(
                l10n.deleteAccountProviderReauthNotice,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (_isDeleting) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                l10n.deleteAccountProgressMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => _confirmAndDelete(controller, l10n),
                child: Text(l10n.deleteAccountButtonLabel),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(
    AuthController controller,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmDialogTitle),
        content: Text(l10n.deleteAccountConfirmDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.deleteAccountCancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.deleteAccountConfirmButtonLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    try {
      await controller.deleteAccount(
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
      );
      showAppMessage(l10n.deleteAccountCompletedMessage);
      // The account is gone, so LaunchGateScreen underneath has already
      // rebuilt into the sign-in screen; this route is just covering it.
      navigator.popUntil((route) => route.isFirst);
    } catch (error, stackTrace) {
      // Same rule as the sign-in screen: the raw exception goes to the
      // developer log, never on screen.
      developer.log(
        'Account deletion failed',
        name: 'AccountDeletionScreen',
        error: error,
        stackTrace: stackTrace,
      );
      final message = _errorMessageFor(error, l10n);
      // Through the app-level messenger, not this screen's.
      //
      // A deletion that fails part-way has usually already removed the
      // account's pets -- which empties the pet list, which makes
      // LaunchGateScreen replace the entire app shell with the "add a pet"
      // screen. This screen goes with it, and an error shown only here goes
      // too: the owner is left in an app emptied of their data with nothing
      // said about why. That is what happened the first time this ran
      // against the real project.
      showAppMessage(message);
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = message;
      });
    }
  }

  String _errorMessageFor(Object error, AppLocalizations l10n) {
    if (error is fb.FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-not-found':
          return l10n.authErrorWrongCredentials;
        case 'requires-recent-login':
          return l10n.deleteAccountRequiresRecentLoginMessage;
        case 'too-many-requests':
          return l10n.authErrorTooManyRequests;
        case 'network-request-failed':
          return l10n.authErrorNetworkRequestFailed;
      }
    }
    return l10n.deleteAccountFailedMessage;
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.deleteAccountWarningTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.deleteAccountWarningBody,
              style: TextStyle(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 8),
            for (final item in [
              l10n.deleteAccountWarningItemPets,
              l10n.deleteAccountWarningItemRecords,
              l10n.deleteAccountWarningItemPhotos,
              l10n.deleteAccountWarningItemAi,
            ])
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('・', style: TextStyle(color: colors.onErrorContainer)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionNoticeCard extends StatelessWidget {
  const _SubscriptionNoticeCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deleteAccountSubscriptionNoticeTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(l10n.deleteAccountSubscriptionNoticeBody),
          ],
        ),
      ),
    );
  }
}
