import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../auth_controller.dart';

/// Key the referral code typed at sign-up is stashed under until the app
/// shell is ready to redeem it (see lib/app/home_shell.dart). Kept here
/// (not in shared/) since it's purely an auth<->app-shell handoff detail,
/// not a cross-feature contract other features need.
const String pendingReferralCodePrefsKey = 'auth.pending_referral_code';

/// Last-used email, remembered so returning users don't have to retype it
/// (PM request). Deliberately email-only: the *password* is intentionally
/// never persisted here -- SharedPreferences on web is backed by
/// localStorage, which isn't secure storage (no encryption, readable by
/// any script on the page), so a raw password would be a real leak risk.
/// The password field instead uses [AutofillHints.password] so the
/// *browser's own* password manager can securely offer to save/autofill
/// it -- same end result (not retyping it) via the mechanism actually
/// built for this.
const String _rememberedEmailPrefsKey = 'auth.remembered_email';

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

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberedEmailPrefsKey);
    if (email != null && mounted) {
      setState(() => _emailController.text = email);
    }
  }

  Future<void> _rememberEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailPrefsKey, email);
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('パスワードを再設定'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            helperText: '登録済みのメールアドレス宛に再設定用のリンクを送信します',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(emailController.text.trim()),
            child: const Text('送信'),
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
      ).showSnackBar(const SnackBar(content: Text('パスワード再設定用のメールを送信しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送信に失敗しました: $e')));
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
    // errorMessage is reset to null at the start of each attempt and only
    // set on failure, so null here means the above actually succeeded.
    if (controller.errorMessage == null) {
      await _rememberEmail(email);
      // Prompts the browser's own password manager to offer saving the
      // credentials just used -- this (not app-side storage) is how the
      // password itself gets "remembered" (see _rememberedEmailPrefsKey's
      // doc comment for why).
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Image.asset('assets/images/wanote_wordmark.png', height: 28),
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
                          _isSignUpMode ? 'Create your account' : 'Sign in',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // AutofillGroup + autofillHints let the *browser's*
                        // password manager offer to save/fill these fields
                        // securely -- see _rememberedEmailPrefsKey's doc
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
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
                                validator: (value) {
                                  if (value == null || !value.contains('@')) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                autofillHints: [
                                  _isSignUpMode
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                ),
                                validator: (value) {
                                  if (value == null || value.length < 6) {
                                    return 'Password must be at least 6 characters';
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
                              child: const Text('パスワードをお忘れですか？'),
                            ),
                          ),
                        if (_isSignUpMode) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _referralCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: '紹介コード（任意）',
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (controller.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              controller.errorMessage!,
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
                          child: Text(_isSignUpMode ? 'Sign up' : 'Sign in'),
                        ),
                        TextButton(
                          onPressed: controller.isLoading
                              ? null
                              : () => setState(
                                  () => _isSignUpMode = !_isSignUpMode,
                                ),
                          child: Text(
                            _isSignUpMode
                                ? 'Already have an account? Sign in'
                                : 'New here? Create an account',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('or'),
                              ),
                              Expanded(child: Divider()),
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
                          label: const Text('Sign in with Google'),
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
                          label: const Text('Sign in with Apple'),
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
