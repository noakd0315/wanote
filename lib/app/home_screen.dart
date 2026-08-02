import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../features/ai/data/ai_backend_client.dart';
import '../features/ai/data/consultation_repository.dart';
import '../features/ai/presentation/consultation_screen.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../features/daily_record/presentation/toilet_record_timeline_screen.dart';
import '../features/daily_record/presentation/weight_record_chart_screen.dart';
import '../features/medical/presentation/prevention/certificate_list_screen.dart';
import '../shared/models/consultation_reference_record.dart';
import '../shared/models/pet_profile.dart';
import '../shared/services/ai_usage_repository.dart';

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
  });

  final String uid;
  final PetProfile activePet;
  final WeightRecordRepository weightRecordRepository;
  final ToiletRecordRepository toiletRecordRepository;
  final AiUsageRepository usageRepository;
  final AiBackendClient backendClient;
  final ConsultationRepository consultationRepository;

  /// Forwarded straight through to [ConsultationScreen], mirroring
  /// HomeShell's `_openPaywall` hook.
  final VoidCallback onRequestUpgrade;

  void _openWeight(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeightRecordChartScreen(
          uid: uid,
          petId: activePet.petId,
          repository: weightRecordRepository,
        ),
      ),
    );
  }

  void _openToilet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToiletRecordTimelineScreen(
          uid: uid,
          petId: activePet.petId,
          repository: toiletRecordRepository,
          onConsultationSuggested: (suggestion) => _openConsultation(
            context,
            prefillRecords: [suggestion.reference],
          ),
        ),
      ),
    );
  }

  void _openCertificates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CertificateListScreen(uid: uid, petId: activePet.petId),
      ),
    );
  }

  void _openConsultation(
    BuildContext context, {
    List<ConsultationReferenceRecord>? prefillRecords,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationScreen(
          uid: uid,
          petId: activePet.petId,
          usageRepository: usageRepository,
          backendClient: backendClient,
          consultationRepository: consultationRepository,
          onRequestUpgrade: onRequestUpgrade,
          prefillRecords: prefillRecords,
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
            CachedNetworkImage(
              imageUrl: activePet.photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const _DefaultBackground(),
            )
          else
            const _DefaultBackground(),
          // Scrim so the overlaid text/buttons stay legible over a photo.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
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
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ShortcutChip(
                        icon: Icons.monitor_weight_outlined,
                        label: '体重',
                        onTap: () => _openWeight(context),
                      ),
                      _ShortcutChip(
                        icon: Icons.wc_outlined,
                        label: 'トイレ',
                        onTap: () => _openToilet(context),
                      ),
                      _ShortcutChip(
                        icon: Icons.description_outlined,
                        label: '証明書',
                        onTap: () => _openCertificates(context),
                      ),
                      _ShortcutChip(
                        icon: Icons.smart_toy_outlined,
                        label: 'AI相談',
                        onTap: () => _openConsultation(context),
                      ),
                    ],
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

/// Simple Flutter-only placeholder used when the active pet has no photo
/// yet -- deliberately not a missing-asset image reference, since no
/// illustration assets exist in this project (per the PM's explicit
/// direction not to source/fabricate one).
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
        child: Icon(
          Icons.pets,
          size: 120,
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.black.withValues(alpha: 0.35),
      onPressed: onTap,
    );
  }
}
