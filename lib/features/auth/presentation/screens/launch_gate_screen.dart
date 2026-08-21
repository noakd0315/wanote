import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/models/auth_provider_type.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../../domain/auth_gate_resolver.dart';
import '../../domain/biometric_fallback_resolver.dart';
import '../auth_controller.dart';
import 'biometric_setup_screen.dart';
import 'pet_profile_form_screen.dart';
import 'pet_profile_switch_screen.dart';
import 'sign_up_screen.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';

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
/// [LaunchGateScreen.homeBuilder] lets a caller outside features/auth supply the real app
/// shell once onboarding is done; it defaults to [PetProfileSwitchScreen]
/// so this feature is usable stand-alone before other features are wired
/// in (main.dart is intentionally left untouched by this feature; wiring
/// main.dart -> LaunchGateScreen is a follow-up step for whoever owns app
/// startup).
class LaunchGateScreen extends StatefulWidget {
  const LaunchGateScreen({super.key, this.homeBuilder});

  final WidgetBuilder? homeBuilder;

  @override
  State<LaunchGateScreen> createState() => _LaunchGateScreenState();
}

class _LaunchGateScreenState extends State<LaunchGateScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A cold start already re-evaluates the gate. This catches the other
    // case: an app left in the background for longer than the session
    // window, which would otherwise come back straight into the content it
    // was showing days ago (see SessionExpiryPolicy).
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<AuthController>().refreshSessionGate());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    // Nothing is known yet, so nothing is claimed yet. Every branch below
    // makes a definite statement about this account -- "you are signed out",
    // "you have no pets" -- and making one too early is what flashed the
    // sign-in and first-pet screens at owners who were neither.
    if (controller.isResolvingSession) {
      return const _ResolvingScreen();
    }

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
        return widget.homeBuilder?.call(context) ??
            const PetProfileSwitchScreen();
    }
  }
}

/// Shown while the gate is still working out which screen is the right one.
///
/// Deliberately says nothing about the account -- no "signing in", no "no
/// pets yet". The whole point is that we do not know yet, and a caption that
/// guesses wrong is the same mistake in words instead of screens.
class _ResolvingScreen extends StatelessWidget {
  const _ResolvingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DogSilhouetteBackground()),
          WanoteLoadingIndicator.centered(),
        ],
      ),
    );
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

  /// PM request: let the user reveal what they typed to confirm it's
  /// correct before submitting, instead of only ever seeing dots.
  bool _obscurePassword = true;

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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await controller.completeReenterPassword(_passwordController.text);
    } catch (e) {
      setState(() => _error = l10n.biometricGateIncorrectPasswordError);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _reauthenticateWithProvider(AuthController controller) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await controller.completeReauthenticateWithProvider();
    } catch (e) {
      setState(() => _error = l10n.biometricGateReauthFailedError);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context)!;
    final fallback = controller.pendingBiometricFallback;
    final provider = controller.currentUser?.authProvider;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.biometricGateAppBarTitle)),
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
                          child: Text(l10n.biometricGateUnlockButton),
                        )
                      else
                        _buildFallback(
                          context,
                          l10n,
                          controller,
                          fallback,
                          provider,
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (!_isBusy) ...[
                        const SizedBox(height: 24),
                        // The way out of a lock that is not "prove you are
                        // the same person". Signing out for real is what
                        // makes replacing sign-out with lock safe: a locked
                        // phone is still signed in, and without this it
                        // could never be handed to someone else or used
                        // with another account (PM, 2026-08-21).
                        TextButton(
                          onPressed: () => unawaited(
                            context.read<AuthController>().signOut(),
                          ),
                          child: Text(
                            l10n.biometricGateUseAnotherAccountButton,
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
    AppLocalizations l10n,
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
            Text(l10n.biometricGateMismatchMessage),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => controller.retryBiometric(),
              child: Text(l10n.biometricGateRetryButton),
            ),
          ],
        );
      case BiometricFallbackAction.reenterPassword:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.biometricGatePasswordPrompt),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _submitPassword(controller),
              child: Text(l10n.biometricGateContinueButton),
            ),
          ],
        );
      case BiometricFallbackAction.reauthenticateWithProvider:
        final label = provider == AuthProviderType.google
            ? l10n.signInWithGoogle
            : l10n.signInWithApple;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.biometricGateReauthPrompt),
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
