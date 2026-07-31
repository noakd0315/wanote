import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/auth.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/billing/presentation/paywall_screen.dart';

/// 設定・課金 section of the app shell.
///
/// Pet switching is entirely delegated to Agent A's [AuthController] /
/// [PetProfileSwitchScreen] -- no pet-switching logic is reimplemented here,
/// per the task's "reuse, don't reimplement" instruction. This section only
/// adds the entry points (switch pets, upgrade, sign out) that make sense to
/// live at the app-shell level since they cut across features.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.activePet,
    required this.billingRepository,
  });

  final PetProfile activePet;
  final BillingRepository billingRepository;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final user = controller.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('設定・課金')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.pets)),
            title: Text(activePet.name),
            subtitle: Text(activePet.breed),
          ),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(user.email),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('ペットを切り替える・追加する'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PetProfileSwitchScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('プランをアップグレード'),
            subtitle: const Text('サブスクリプション・AI相談チケットの購入'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PaywallScreen(billingRepository: billingRepository),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('サインアウト'),
            onTap: () => controller.signOut(),
          ),
        ],
      ),
    );
  }
}
