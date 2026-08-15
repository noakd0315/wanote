import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/auth.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/billing/presentation/paywall_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/services/announcement_repository.dart';
import '../shared/services/locale_controller.dart';
import '../shared/widgets/language_picker.dart';
import '../shared/widgets/pet_icon_avatar.dart';
import 'announcements_screen.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final localeController = context.watch<LocaleController>();
    final languageOverride = localeController.locale;

    // No Scaffold/AppBar here -- HomeShell's outer AppBar already covers
    // every section, matching AiSection/DailyRecordSection/MedicalHomeScreen.
    return ListView(
      children: [
        ListTile(
          leading: PetIconAvatar(pet: activePet),
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
          title: Text(l10n.switchPetMenuTitle),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PetProfileSwitchScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l10n.upgradePlanMenuTitle),
          subtitle: Text(l10n.upgradePlanMenuSubtitle),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PaywallScreen(billingRepository: billingRepository),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: Text(l10n.announcementsMenuTitle),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnnouncementsScreen(
                repository: FirestoreAnnouncementRepository(),
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.languageMenuTitle),
          subtitle: Text(
            languageOverride == null
                ? l10n.languageMenuSubtitleSystem
                : localeEndonym(languageOverride),
          ),
          onTap: () => showLanguagePicker(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.signOutMenuTitle),
          onTap: () => controller.signOut(),
        ),

        // Deliberately far from sign-out.
        //
        // These two used to be adjacent rows, told apart only by colour, and
        // the PM reached for sign-out and hit account deletion instead
        // (2026-08-16). Red text does not help a thumb that has already
        // started moving: the two need to be different distances away, not
        // just different colours. Nothing else goes in this gap -- the empty
        // space is the safeguard.
        //
        // It stays reachable from inside the app either way, which App Store
        // Review Guideline 5.1.1(v) requires.
        const SizedBox(height: 48),
        const Divider(),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            l10n.deleteAccountMenuTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          // Says what it costs, on the row itself. Someone who has tapped it
          // by mistake should learn that from here, not from the next screen.
          subtitle: Text(l10n.deleteAccountMenuSubtitle),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccountDeletionScreen()),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
