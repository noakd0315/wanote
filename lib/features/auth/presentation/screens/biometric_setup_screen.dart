import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../auth_controller.dart';

/// Shown exactly once, immediately after first registration (spec 1.2 -
/// 生体認証設定画面：初回登録直後に「生体認証を有効にしますか」を確認).
///
/// LaunchGateScreen only routes here when
/// `AuthController.biometricAvailable` is true; if the device has no
/// usable biometric enrollment this screen is skipped entirely per spec
/// 1.4 ("生体認証が端末非対応／未設定の場合は自動的にパスワード認証のみの
/// 導線にする").
class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isBusy = false;

  Future<void> _enable(AuthController controller) async {
    setState(() => _isBusy = true);
    await controller.setBiometricEnabled(true);
    controller.markOnboardingComplete();
  }

  void _skip(AuthController controller) {
    controller.markOnboardingComplete();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.biometricSetupAppBarTitle)),
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
                      Text(
                        l10n.biometricSetupHeadline,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.biometricSetupDescription,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isBusy ? null : () => _enable(controller),
                        child: Text(l10n.biometricSetupEnableButton),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isBusy ? null : () => _skip(controller),
                        child: Text(l10n.biometricSetupSkipButton),
                      ),
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
}
