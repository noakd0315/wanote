import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_controller.dart';

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

  /// true = create a new account, false = sign in to an existing one.
  bool _isSignUpMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailForm(AuthController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSignUpMode) {
      await controller.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      await controller.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('wanote')),
      body: SafeArea(
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
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
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
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
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
                          : () => setState(() => _isSignUpMode = !_isSignUpMode),
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
                          : () => controller.signInWithGoogle(),
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Sign in with Google'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: controller.isLoading
                          ? null
                          : () => controller.signInWithApple(),
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
    );
  }
}
