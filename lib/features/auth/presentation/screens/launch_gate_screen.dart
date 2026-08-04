import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/models/auth_provider_type.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../../domain/auth_gate_resolver.dart';
import '../../domain/biometric_fallback_resolver.dart';
import '../auth_controller.dart';
import 'biometric_setup_screen.dart';
import 'pet_profile_form_screen.dart';
import 'pet_profile_switch_screen.dart';
import 'sign_up_screen.dart';

/// The app's initial route (spec 1.2 - 起動時ログイン画面).
///
/// Purely reactive: it watches [AuthController] and renders whatever the
/// current state implies, layering two decisions on top of each other:
///
/// 1. [AuthGateResolver]'s [AuthGateAction] - the returning-user gate
///    (sign in / biometric prompt / straight into the app).
/// 2. On top of `enterApp`, a one-time post-registration onboarding chain
///    (biometric setup, if available, then the forced first pet profile)
///    driven by [AuthController.justRegistered] and the live pet list.
///
/// [homeBuilder] lets a caller outside features/auth supply the real app
/// shell once onboarding is done; it defaults to [PetProfileSwitchScreen]
/// so this feature is usable stand-alone before other features are wired
/// in (main.dart is intentionally left untouched by this feature; wiring
/// main.dart -> LaunchGateScreen is a follow-up step for whoever owns app
/// startup).
class LaunchGateScreen extends StatelessWidget {
  const LaunchGateScreen({super.key, this.homeBuilder});

  final WidgetBuilder? homeBuilder;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    switch (controller.gateAction) {
      case AuthGateAction.requireSignIn:
        return const SignUpScreen();
      case AuthGateAction.requireBiometric:
        return const _BiometricGate();
      case AuthGateAction.enterApp:
        if (controller.justRegistered) {
          if (controller.biometricAvailable) {
            return const BiometricSetupScreen();
          }
          // Spec 1.4: no usable biometric enrollment -> skip straight past
          // the biometric-setup step into the normal post-registration
          // flow (first pet creation). Deferred to a post-frame callback
          // because calling markOnboardingComplete() here synchronously
          // would call notifyListeners() while this very widget is still
          // being built ("setState() or markNeedsBuild() called during
          // build" -- caught during local emulator verification).
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller.markOnboardingComplete(),
          );
        }
        if (controller.pets.isEmpty) {
          return const PetProfileFormScreen();
        }
        return homeBuilder?.call(context) ?? const PetProfileSwitchScreen();
    }
  }
}

/// Drives the biometric prompt + its fallback chain
/// (BiometricFallbackResolver) for returning users with biometric login
/// enabled.
class _BiometricGate extends StatefulWidget {
  const _BiometricGate();

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate> {
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptNow());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _promptNow() async {
    final controller = context.read<AuthController>();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    await controller.promptBiometric();
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _submitPassword(AuthController controller) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await controller.completeReenterPassword(_passwordController.text);
    } catch (e) {
      setState(() => _error = 'Incorrect password. Try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _reauthenticateWithProvider(AuthController controller) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await controller.completeReauthenticateWithProvider();
    } catch (e) {
      setState(() => _error = 'Sign-in was not completed.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final fallback = controller.pendingBiometricFallback;
    final provider = controller.currentUser?.authProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Unlock wanote')),
      body: Stack(
        children: [
          const Positioned.fill(child: DogSilhouetteBackground()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, size: 64),
                      const SizedBox(height: 16),
                      if (_isBusy)
                        const CircularProgressIndicator()
                      else if (fallback == null)
                        FilledButton(
                          onPressed: _promptNow,
                          child: const Text('Unlock'),
                        )
                      else
                        _buildFallback(context, controller, fallback, provider),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(
    BuildContext context,
    AuthController controller,
    BiometricFallbackAction fallback,
    AuthProviderType? provider,
  ) {
    switch (fallback) {
      case BiometricFallbackAction.enterApp:
        // Handled by AuthController flipping gateAction; nothing to render.
        return const SizedBox.shrink();
      case BiometricFallbackAction.retryBiometric:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Biometric authentication did not match.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => controller.retryBiometric(),
              child: const Text('Try again'),
            ),
          ],
        );
      case BiometricFallbackAction.reenterPassword:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your password to continue.'),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _submitPassword(controller),
              child: const Text('Continue'),
            ),
          ],
        );
      case BiometricFallbackAction.reauthenticateWithProvider:
        final label = provider == AuthProviderType.google
            ? 'Sign in with Google'
            : 'Sign in with Apple';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please sign in again to continue.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _reauthenticateWithProvider(controller),
              child: Text(label),
            ),
          ],
        );
    }
  }
}
