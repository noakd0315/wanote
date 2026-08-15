import 'dart:async';

import 'package:flutter/material.dart';

import '../features/ai/data/ai_backend_client.dart';
import '../features/ai/presentation/food_portion_screen.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/models/pet_profile.dart';
import '../shared/services/ai_usage_repository.dart';
import '../shared/widgets/pet_background_photo.dart';
import '../features/ai/data/consultation_repository.dart';

/// Whether [HomeScreen] should render the active pet's photo as its
/// background, vs. falling back to the default illustration. Factored out
/// as a pure function (rather than inlined in build()) so it's unit
/// testable without a widget binding -- see test/app/home_screen_test.dart.
bool shouldShowPetPhotoBackground(String? photoUrl) =>
    photoUrl != null && photoUrl.trim().isNotEmpty;

/// New home/dashboard screen (app-shell-owned, not inside any feature/
/// directory -- it composes screens from daily_record/medical/ai but isn't
/// itself owned by any single feature agent).
///
/// Shows the active pet's photo full-bleed as a background (or a simple
/// Flutter-only illustration placeholder when no photo has been uploaded
/// yet -- there are no illustration image assets in this project), with
/// the pet's name and a handful of navigation shortcuts overlaid.
///
/// Per the PM's request, 体重/トイレ/証明書 (used often) are *direct*
/// shortcuts implemented as plain `Navigator.push` straight to their
/// screens. 日常記録/医療 are deliberately NOT shortcuts here -- they're
/// already one tap away via the bottom nav bar, so duplicating them on the
/// home screen was redundant (removed per the PM's explicit request). AI相談
/// stays since it isn't otherwise a direct shortcut. This screen deliberately
/// does not reach into [HomeShell]'s private `IndexedStack`/`_selectedIndex`
/// state; direct navigation keeps Home decoupled from the shell's internals.
///
/// IMPORTANT: `Navigator.of(context)` here resolves to [HomeShell]'s own
/// inner shell `Navigator` (not the app's root one) because this screen is
/// rendered inside it -- that's what keeps the bottom nav bar visible while
/// these shortcuts are open. See home_shell.dart's doc comment.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.uid,
    required this.activePet,
    required this.weightRecordRepository,
    required this.toiletRecordRepository,
    required this.usageRepository,
    required this.backendClient,
    required this.consultationRepository,
    required this.onRequestUpgrade,
    required this.onOpenWeight,
    required this.onOpenToilet,
    required this.onOpenCertificates,
  });

  final String uid;
  final PetProfile activePet;
  final WeightRecordRepository weightRecordRepository;
  final ToiletRecordRepository toiletRecordRepository;
  final AiUsageRepository usageRepository;
  final AiBackendClient backendClient;

  /// Passed through to the food-portion screen, which now keeps its advice
  /// in the same history as a typed consultation.
  final ConsultationRepository consultationRepository;

  /// Forwarded straight through to [ConsultationScreen], mirroring
  /// HomeShell's `_openPaywall` hook.
  final VoidCallback onRequestUpgrade;

  /// Shortcuts hand these back to HomeShell, which switches to the section
  /// and inner tab that owns the screen.
  ///
  /// They used to push the destination directly from here, which arrived
  /// without the tab strip its section normally shows -- the same screen
  /// looked different depending on whether you reached it from a shortcut or
  /// from the bottom nav bar (PM report). Only the shell can switch sections,
  /// so the decision has to live there.
  final VoidCallback onOpenWeight;
  final VoidCallback onOpenToilet;
  final VoidCallback onOpenCertificates;

  Future<void> _openFoodPortion(BuildContext context) async {
    // Resolve the latest known weight before navigating so
    // FoodPortionScreen can be pre-filled -- it takes a plain double rather
    // than the repository itself, mirroring how ReportScreen receives
    // MonthlyReportInputStats instead of reaching into daily_record itself.
    final records = await weightRecordRepository
        .watchAll(uid, activePet.petId)
        .first;
    final latestWeightKg = records.isEmpty
        ? activePet.weightKg
        : records
              .reduce((a, b) => a.measuredAt.isAfter(b.measuredAt) ? a : b)
              .weightKg;
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodPortionScreen(
          uid: uid,
          petId: activePet.petId,
          birthday: activePet.birthday,
          neutered: activePet.neutered,
          initialWeightKg: latestWeightKg,
          usageRepository: usageRepository,
          backendClient: backendClient,
          consultationRepository: consultationRepository,
          onRequestUpgrade: onRequestUpgrade,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPhoto = shouldShowPetPhotoBackground(activePet.photoUrl);

    // No AppBar here -- HomeShell's outer Scaffold already renders a
    // persistent "wanote" AppBar above every section (see its doc comment),
    // so this screen just fills the body area below it.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showPhoto)
            PetBackgroundPhoto(
              pet: activePet,
              errorWidget: const _DefaultBackground(),
            )
          else
            const _DefaultBackground(),
          // PM request: remove the black gradient scrim that used to sit
          // here for text contrast -- the overlaid name/shortcuts now rely
          // on their own text shadow / chip background instead (see below).
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    activePet.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      // Keeps the name legible over a bright photo now that
                      // the full-screen black gradient scrim is gone (PM
                      // request: "黒のグラデーションがかかっていますが、
                      // 削除したい").
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: HomeShortcutRow(
                    onWeight: onOpenWeight,
                    onToilet: onOpenToilet,
                    onCertificates: onOpenCertificates,
                    onFoodPortion: () => unawaited(_openFoodPortion(context)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder used when the active pet has no photo yet -- shows the
/// wanote mascot illustration (PM-provided artwork) rather than a bare
/// Material icon.
class _DefaultBackground extends StatelessWidget {
  const _DefaultBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Center(
        // Sized relative to screen width (PM request: "デフォルト表示アイコン
        // を大きく表示したい") rather than a fixed px width, so it stays
        // prominent across phone sizes without overflowing narrow screens.
        child: Image.asset(
          'assets/images/wanote_icon.png',
          width: MediaQuery.sizeOf(context).width * 0.75,
        ),
      ),
    );
  }
}

/// The Home screen's row of shortcuts.
///
/// Public and free of repositories so its layout can be tested directly --
/// equal sizing is the whole point of it and is invisible in a diff.
///
/// Equal-width [Expanded] tiles inside an [IntrinsicHeight], rather than a
/// [Wrap] of self-sizing chips: that is what makes every shortcut the same
/// size no matter how long its label is (PM request: "サイズを統一したい"),
/// in both languages, without hardcoding a width.
class HomeShortcutRow extends StatelessWidget {
  const HomeShortcutRow({
    super.key,
    required this.onWeight,
    required this.onToilet,
    required this.onCertificates,
    required this.onFoodPortion,
  });

  final VoidCallback onWeight;
  final VoidCallback onToilet;
  final VoidCallback onCertificates;
  final VoidCallback onFoodPortion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shortcuts = <_ShortcutButton>[
      _ShortcutButton(
        icon: Icons.monitor_weight_outlined,
        label: l10n.homeShortcutWeightLabel,
        onTap: onWeight,
      ),
      _ShortcutButton(
        icon: Icons.wc_outlined,
        label: l10n.homeShortcutToiletLabel,
        onTap: onToilet,
      ),
      _ShortcutButton(
        icon: Icons.description_outlined,
        label: l10n.homeShortcutCertificatesLabel,
        onTap: onCertificates,
      ),
      _ShortcutButton(
        icon: Icons.restaurant_outlined,
        label: l10n.homeShortcutFoodPortionLabel,
        onTap: onFoodPortion,
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shortcuts.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: shortcuts[i]),
          ],
        ],
      ),
    );
  }
}

/// One Home shortcut: a card with a coloured icon badge and its label
/// underneath.
///
/// Replaces a translucent-black `ActionChip`, which was hard to read and
/// sized itself to its label so no two shortcuts matched (PM request: unify
/// the size, and make them legible over any background photo).
///
/// Legibility here does not depend on the photo behind it. The card is a
/// near-opaque theme surface with a shadow, so the label always sits on a
/// known colour -- a translucent scrim only works until someone sets a
/// background bright or busy enough to compete with it.
class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    return Material(
      // Not fully opaque, so a hint of the photo still reads through and the
      // row doesn't look pasted on -- but far short of letting it interfere.
      color: colorScheme.surface.withValues(alpha: 0.93),
      borderRadius: radius,
      elevation: 3,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
