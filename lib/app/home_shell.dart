import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ai/data/ai_backend_client.dart';
import '../features/ai/data/consultation_repository.dart';
import '../features/ai/data/report_repository.dart';
import '../features/ai/domain/monthly_report_generator.dart';
import '../features/ai/presentation/consultation_screen.dart';
import '../features/auth/auth.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/billing/data/campaign_code_repository.dart';
import '../features/billing/domain/campaign_code_models.dart';
import '../features/billing/presentation/paywall_screen.dart';
import '../features/daily_record/data/health_record_repository.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../features/medical/presentation/medical_home_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/services/ai_usage_repository.dart';
import '../shared/widgets/dog_silhouette_background.dart';
import 'ai_section.dart';
import 'daily_record_section.dart';
import 'home_screen.dart';
import 'settings_section.dart';

/// The real app shell, handed to [LaunchGateScreen] as its `homeBuilder`
/// from main.dart once a signed-in user has at least one pet.
///
/// Owns construction of every concrete repository the 5 sections need
/// (daily_record / medical / ai / billing all expose repository
/// interfaces + Firestore-backed implementations but no shared DI
/// container), and renders a 5-destination bottom navigation bar across
/// them: ホーム / 日常記録 / 医療 / AI相談 / 設定・課金 (spec's top-level IA
/// plus a dashboard home screen).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.uid, required this.activePet});

  final String uid;
  final PetProfile activePet;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Owns navigation *within* the shell (e.g. Home's 体重/トイレ/証明書/AI相談
  /// shortcuts, or any section's own internal pushes). Wrapping the tab
  /// content in this inner [Navigator] -- rather than letting those pushes
  /// fall through to the app's root `Navigator` from `MaterialApp` -- is what
  /// keeps [NavigationBar] visible while a shortcut screen is open; without
  /// it, a pushed route would cover the whole [Scaffold], footer included.
  final _shellNavigatorKey = GlobalKey<NavigatorState>();

  late final HealthRecordRepository _healthRecordRepository;
  late final WeightRecordRepository _weightRecordRepository;
  late final ToiletRecordRepository _toiletRecordRepository;
  late final AiUsageRepository _aiUsageRepository;
  late final AiBackendClient _aiBackendClient;
  late final ConsultationRepository _consultationRepository;
  late final ReportRepository _reportRepository;
  late final MonthlyReportGenerator _reportGenerator;
  late final BillingRepository _billingRepository;
  late final CampaignCodeRepository _campaignCodeRepository;

  @override
  void initState() {
    super.initState();
    _healthRecordRepository = FirestoreHealthRecordRepository();
    _weightRecordRepository = FirestoreWeightRecordRepository();
    _toiletRecordRepository = FirestoreToiletRecordRepository();
    _aiUsageRepository = FirestoreAiUsageRepository();
    _aiBackendClient = AiBackendClient.fromEnvironment();
    _consultationRepository = FirestoreConsultationRepository();
    _reportRepository = FirestoreReportRepository();
    _reportGenerator = BackendMonthlyReportGenerator(_aiBackendClient);
    _billingRepository = RevenueCatBillingRepository();
    _campaignCodeRepository = FirestoreCampaignCodeRepository();
    unawaited(_initializeBilling());
    unawaited(_redeemPendingReferralCodeIfAny());
  }

  Future<void> _initializeBilling() async {
    // Both configure() and logIn() are documented no-ops until
    // BillingConfig.isConfigured (i.e. a RevenueCat API key has been
    // supplied via --dart-define), so this is safe to fire-and-forget
    // before RevenueCat has been provisioned. The try/catch is extra
    // insurance so a future change to that no-op behavior can never take
    // down the rest of the app shell.
    try {
      await _billingRepository.configure();
      await _billingRepository.logIn(widget.uid);
    } catch (_) {
      // Best-effort only.
    }
  }

  /// If the user typed a referral code on [SignUpScreen], it's sitting in
  /// SharedPreferences (auth doesn't depend on features/billing, so it
  /// couldn't redeem it itself) -- this is the one place both auth's
  /// hand-off and billing's redemption flow are already in scope, so it's
  /// where the "started the app via a referral code -> automatically get a
  /// promotional code" flow actually happens. Cleared either way so a
  /// failed attempt doesn't retry forever on every future launch.
  Future<void> _redeemPendingReferralCodeIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(pendingReferralCodePrefsKey);
    if (code == null || code.isEmpty) return;
    await prefs.remove(pendingReferralCodePrefsKey);

    try {
      final result = await _campaignCodeRepository.redeem(
        code: code,
        uid: widget.uid,
      );
      if (result is CampaignCodeRedeemed && mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.referralCodeAppliedMessage)),
        );
      }
    } catch (_) {
      // Best-effort only -- the user can still redeem manually from the
      // paywall's promotion-code section if this silently fails.
    }
  }

  @override
  void dispose() {
    _billingRepository.dispose();
    super.dispose();
  }

  void _openConsultation(
    BuildContext context, {
    List<ConsultationReferenceRecord>? prefillRecords,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationScreen(
          uid: widget.uid,
          petId: widget.activePet.petId,
          usageRepository: _aiUsageRepository,
          backendClient: _aiBackendClient,
          consultationRepository: _consultationRepository,
          onRequestUpgrade: () => _openPaywall(context),
          prefillRecords: prefillRecords,
        ),
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(billingRepository: _billingRepository),
      ),
    );
  }

  /// Built on demand from inside the shell Navigator's route builder rather
  /// than once per [build]: the route is generated a single time (see
  /// onGenerateRoute below), so a list captured in `build`'s scope would
  /// freeze at whichever pet was active when the shell first mounted. Every
  /// section here is keyed off [HomeShellState.widget.activePet], so
  /// switching pets has to re-read it -- PM report: after switching pets the
  /// 医療 tab kept showing the previous pet's records until a full reload.
  List<Widget> _buildSections(BuildContext context) {
    final uid = widget.uid;
    final petId = widget.activePet.petId;

    return <Widget>[
      HomeScreen(
        uid: uid,
        activePet: widget.activePet,
        weightRecordRepository: _weightRecordRepository,
        toiletRecordRepository: _toiletRecordRepository,
        usageRepository: _aiUsageRepository,
        backendClient: _aiBackendClient,
        consultationRepository: _consultationRepository,
        onRequestUpgrade: () => _openPaywall(context),
      ),
      DailyRecordSection(
        uid: uid,
        petId: petId,
        healthRecordRepository: _healthRecordRepository,
        weightRecordRepository: _weightRecordRepository,
        toiletRecordRepository: _toiletRecordRepository,
        onConsultationSuggested: (suggestion) =>
            _openConsultation(context, prefillRecords: [suggestion.reference]),
      ),
      MedicalHomeScreen(uid: uid, petId: petId),
      AiSection(
        uid: uid,
        petId: petId,
        petName: widget.activePet.name,
        usageRepository: _aiUsageRepository,
        backendClient: _aiBackendClient,
        consultationRepository: _consultationRepository,
        reportRepository: _reportRepository,
        reportGenerator: _reportGenerator,
        weightRecordRepository: _weightRecordRepository,
        toiletRecordRepository: _toiletRecordRepository,
        onRequestUpgrade: () => _openPaywall(context),
      ),
      SettingsSection(
        activePet: widget.activePet,
        billingRepository: _billingRepository,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Only shown on the ホーム tab (index 0) per the PM's request ("TOP画面
      // 以外ヘッダーをなくしたい") -- every other tab/pushed screen now has no
      // header chrome at all. `centerTitle: false` + `titleSpacing: 0` pins
      // the logo flush to the leading edge with no extra gap (PM: "ヘッダー
      // のアイコンは寄せとしてください").
      appBar: _selectedIndex == 0
          ? AppBar(
              centerTitle: false,
              titleSpacing: 0,
              title: Image.asset(
                'assets/images/wanote_wordmark.png',
                height: 28,
              ),
            )
          : null,
      // The dog-silhouette pattern sits behind the Navigator so it shows
      // through the 4 tab-root sections that don't paint their own opaque
      // background (DailyRecordSection/MedicalHomeScreen/AiSection/
      // SettingsSection are bare Column/ListView content) -- HomeScreen
      // (tab 0) keeps its own dedicated photo/gradient background instead,
      // and individual screens pushed on top of a tab (their own Scaffold)
      // still cover it, same as they'd cover any other backdrop.
      body: Stack(
        children: [
          const Positioned.fill(child: DogSilhouetteBackground()),
          Navigator(
            key: _shellNavigatorKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: settings,
              builder: (routeContext) => IndexedStack(
                index: _selectedIndex,
                children: _buildSections(routeContext),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          // Switching tabs always returns to the tab's root -- otherwise
          // tapping e.g. 医療 while a shortcut screen is still pushed on top
          // would leave that stale screen visible instead of the new tab.
          _shellNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHomeLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_note_outlined),
            selectedIcon: const Icon(Icons.event_note),
            label: l10n.navDailyRecordLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.medical_information_outlined),
            selectedIcon: const Icon(Icons.medical_information),
            label: l10n.navMedicalLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.smart_toy_outlined),
            selectedIcon: const Icon(Icons.smart_toy),
            label: l10n.navAiConsultationLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettingsLabel,
          ),
        ],
      ),
    );
  }
}
