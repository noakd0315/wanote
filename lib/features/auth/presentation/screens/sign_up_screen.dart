import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../../data/auth_prefs_keys.dart';
import '../auth_controller.dart';

/// Key the referral code typed at sign-up is stashed under until the app
/// shell is ready to redeem it (see lib/app/home_shell.dart).
const String pendingReferralCodePrefsKey = AuthPrefsKeys.pendingReferralCode;

/// Last-used email, remembered so returning users don't have to retype it
/// (PM request). Deliberately email-only: the *password* is intentionally
/// never persisted here -- SharedPreferences on web is backed by
/// localStorage, which isn't secure storage (no encryption, readable by
/// any script on the page), so a raw password would be a real leak risk.
/// The password field instead uses [AutofillHints.password] so the
/// *browser's own* password manager can securely offer to save/autofill
/// it -- same end result (not retyping it) via the mechanism actually
/// built for this.
const String rememberedEmailPrefsKey = AuthPrefsKeys.rememberedEmail;

/// Initial registration / sign-in screen (spec 1.2 - 初回登録画面).
///
/// Implements both email/password registration and Sign in with
/// Google/Apple regardless of platform: offering both is what satisfies
/// Apple's "if you offer a third-party login you must also offer Sign in
/// with Apple" App Store review requirement (spec 1.4's open question).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  /// true = create a new account, false = sign in to an existing one.
  /// Defaults to sign-in (PM request: the app's initial screen should be
  /// sign-in, not registration) -- new users still reach registration via
  /// the "New here? Create an account" toggle below.
  bool _isSignUpMode = false;

  /// PM request: let the user reveal what they typed to confirm it's
  /// correct before submitting, instead of only ever seeing dots.
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(rememberedEmailPrefsKey);
    if (email != null && mounted) {
      setState(() => _emailController.text = email);
    }
  }

  Future<void> _rememberEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(rememberedEmailPrefsKey, email);
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.forgotPasswordDialogTitle),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.emailLabel,
            helperText: l10n.forgotPasswordDialogHelperText,
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(emailController.text.trim()),
            child: Text(l10n.sendButton),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    final controller = context.read<AuthController>();
    try {
      await controller.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordResetEmailSent)));
    } catch (e, stackTrace) {
      // Full exception -> developer log only; the user gets a generic
      // friendly message (PM report: raw SDK error text was showing on
      // screen).
      developer.log(
        'sendPasswordResetEmail failed',
        name: 'SignUpScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordResetEmailFailed)));
    }
  }

  /// Maps [AuthController.errorCode] (a stable machine code like Firebase
  /// Auth's `e.code`) to a friendly localized message. Falls back to
  /// [AppLocalizations.authErrorGeneric] for any code not explicitly
  /// handled -- the full exception is always logged for developers via
  /// [developer.log] in AuthController, never shown here (PM report: raw
  /// SDK error text, e.g. a Firestore NOT_FOUND dump, was showing directly
  /// on this screen).
  String _authErrorMessage(AppLocalizations l10n, String code) {
    switch (code) {
      case 'email-already-in-use':
        return l10n.authErrorEmailAlreadyInUse;
      case 'invalid-email':
        return l10n.authErrorInvalidEmail;
      case 'weak-password':
        return l10n.authErrorWeakPassword;
      // Deliberately mapped to the same message as wrong-password/
      // user-not-found: telling the user *which* one it was would let an
      // attacker enumerate registered email addresses.
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return l10n.authErrorWrongCredentials;
      case 'user-disabled':
        return l10n.authErrorUserDisabled;
      case 'too-many-requests':
        return l10n.authErrorTooManyRequests;
      case 'network-request-failed':
        return l10n.authErrorNetworkRequestFailed;
      case 'account-exists-with-different-credential':
        return l10n.authErrorAccountExistsWithDifferentCredential;
      default:
        // Unrecognized codes used to show nothing but "問題が発生しました",
        // which is also what a forced sign-out looks like -- during the
        // emulator-connection bug that cost a whole debugging session: the
        // real cause was an "API key not valid" rejection, and the screen
        // gave no way to tell it apart from single-session enforcement.
        // Debug builds only, so nothing leaks to users; and only for codes
        // that aren't mapped, so the deliberate merging of
        // wrong-password/user-not-found above is left intact.
        return kDebugMode
            ? '${l10n.authErrorGeneric} [$code]'
            : l10n.authErrorGeneric;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  /// Stashes the typed referral code (if any) so [HomeShell] can redeem it
  /// once the new account has an active pet and the billing system is up --
  /// this screen must not depend on features/billing directly (auth doesn't
  /// own promotional-code redemption), so it only persists a plain string.
  Future<void> _stashReferralCodeIfProvided() async {
    final code = _referralCodeController.text.trim();
    if (code.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingReferralCodePrefsKey, code);
  }

  Future<void> _submitEmailForm(AuthController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    if (_isSignUpMode) {
      await _stashReferralCodeIfProvided();
      await controller.signUpWithEmail(
        email: email,
        password: _passwordController.text,
      );
    } else {
      await controller.signInWithEmail(
        email: email,
        password: _passwordController.text,
      );
    }
    // errorCode is reset to null at the start of each attempt and only
    // set on failure, so null here means the above actually succeeded.
    if (controller.errorCode == null) {
      await _rememberEmail(email);
      // Prompts the browser's own password manager to offer saving the
      // credentials just used -- this (not app-side storage) is how the
      // password itself gets "remembered" (see rememberedEmailPrefsKey's
      // doc comment for why).
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context)!;

    if (controller.wasForcedSignedOut) {
      controller.clearForcedSignOutFlag();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.forcedSignOutMessage)));
      });
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Image.asset('assets/images/wanote_wordmark.png', height: 28),
        actions: const [LanguageIconButton()],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: DogSilhouetteBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUpMode
                              ? l10n.createAccountTitle
                              : l10n.signInTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // AutofillGroup + autofillHints let the *browser's*
                        // password manager offer to save/fill these fields
                        // securely -- see rememberedEmailPrefsKey's doc
                        // comment for why the app itself only remembers the
                        // email, never the password.
                        AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: l10n.emailLabel,
                                ),
                                validator: (value) {
                                  if (value == null || !value.contains('@')) {
                                    return l10n.emailValidationError;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: [
                                  _isSignUpMode
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: l10n.passwordLabel,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.length < 6) {
                                    return l10n.passwordValidationError;
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        if (!_isSignUpMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: controller.isLoading
                                  ? null
                                  : _forgotPassword,
                              child: Text(l10n.forgotPasswordLink),
                            ),
                          ),
                        if (_isSignUpMode) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _referralCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: l10n.referralCodeLabel,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (controller.errorCode != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _authErrorMessage(l10n, controller.errorCode!),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: controller.isLoading
                              ? null
                              : () => _submitEmailForm(controller),
                          child: Text(
                            _isSignUpMode
                                ? l10n.signUpButton
                                : l10n.signInButton,
                          ),
                        ),
                        TextButton(
                          onPressed: controller.isLoading
                              ? null
                              : () => setState(
                                  () => _isSignUpMode = !_isSignUpMode,
                                ),
                          child: Text(
                            _isSignUpMode
                                ? l10n.switchToSignInLink
                                : l10n.switchToSignUpLink,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(l10n.orDivider),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.isLoading
                              ? null
                              : () async {
                                  await _stashReferralCodeIfProvided();
                                  await controller.signInWithGoogle();
                                },
                          icon: const Icon(Icons.g_mobiledata),
                          label: Text(l10n.signInWithGoogle),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: controller.isLoading
                              ? null
                              : () async {
                                  await _stashReferralCodeIfProvided();
                                  await controller.signInWithApple();
                                },
                          icon: const Icon(Icons.apple),
                          label: Text(l10n.signInWithApple),
                        ),
                        if (controller.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
