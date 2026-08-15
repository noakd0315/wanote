import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ai/data/ai_backend_client.dart';
import '../features/ai/data/consultation_repository.dart';
import '../features/ai/data/report_repository.dart';
import '../features/ai/domain/monthly_report_generator.dart';
import '../features/ai/presentation/consultation_screen.dart';
import '../features/auth/auth.dart';
import '../features/billing/ads/ad_gate.dart';
import '../features/billing/ads/ad_manager.dart';
import '../features/billing/ads/ad_preparer.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/billing/data/campaign_code_repository.dart';
import '../features/billing/domain/ad_policy.dart';
import '../features/billing/domain/campaign_code_models.dart';
import '../features/billing/presentation/paywall_screen.dart';
import '../features/daily_record/data/health_record_repository.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../features/medical/data/medication_repository.dart';
import '../features/medical/data/prevention_program_repository.dart';
import '../features/medical/data/prevention_record_repository.dart';
import '../features/medical/data/reminder_sync_service.dart';
import '../features/medical/notifications/reminder_notification_adapter.dart';
import '../features/medical/presentation/medical_home_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/services/ai_usage_repository.dart';
import '../shared/services/announcement_repository.dart';
import '../shared/widgets/announcement_banner.dart';
import '../shared/widgets/dog_silhouette_background.dart';
import 'ai_section.dart';
import 'announcements_screen.dart';
import 'daily_record_section.dart';
import 'home_screen.dart';
import 'settings_section.dart';
import '../features/medical/domain/reminder_strings.dart';
import '../features/medical/domain/reminder_scheduler.dart';
import '../features/medical/domain/medication_reminder_scheduler.dart';

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

  /// Lets the Home shortcuts put a section on a particular inner tab.
  ///
  /// The sections live in an IndexedStack and keep their own TabControllers,
  /// so they cannot simply be rebuilt with a different starting tab -- a
  /// notifier is how a request reaches one that is already alive.
  final ValueNotifier<int> _dailyRecordTabRequest = ValueNotifier<int>(0);
  final ValueNotifier<int> _medicalTabRequest = ValueNotifier<int>(0);

  /// Jumps to [sectionIndex] with its inner tab set, exactly as if the user
  /// had used the bottom nav bar and then the tab strip.
  ///
  /// PM report: shortcuts used to push the destination screen bare, so it
  /// arrived without the tab strip its section normally shows -- the same
  /// screen looked different depending on how you got to it.
  void _openSectionTab(
    int sectionIndex,
    ValueNotifier<int> tabRequest,
    int tabIndex,
  ) {
    tabRequest.value = tabIndex;
    _shellNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _selectedIndex = sectionIndex);
  }

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
  ReminderSyncService? _reminderSyncService;
  late final AdManager _adManager;
  late final AdGate _adGate;
  final AnnouncementRepository _announcementRepository =
      FirestoreAnnouncementRepository();

  /// Watched so the reminder schedule follows the household: adding or
  /// removing a pet has to add or remove its reminders.
  AuthController? _authController;
  List<String> _trackedPetIds = const [];

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
    // Reads the billing repository's *current* status on every check rather
    // than capturing it: the answer changes the moment RevenueCat replies,
    // and a captured "unknown" would keep ads off forever.
    _adManager = AdManager(
      currentPolicy: () =>
          AdPolicy.fromStatus(_billingRepository.currentPremiumStatus),
    );
    _adGate = AdGate(
      manager: _adManager,
      premiumStatus: () => _billingRepository.currentPremiumStatus,
    );
    unawaited(_prepareAds());
    // Built in didChangeDependencies instead: the notification wording has
    // to come from AppLocalizations, which is not available in initState.
    unawaited(_initializeBilling());
    unawaited(_redeemPendingReferralCodeIfAny());

    // read, not watch: this is a one-time hook-up, not a rebuild dependency.
    _authController = context.read<AuthController>()
      ..addListener(_onPetsChanged);
    _onPetsChanged();
  }

  /// Language for the notifications, and the schedule that carries it.
  ///
  /// Reminders fire days later with the app closed, so their wording is
  /// resolved now and handed to the scheduler. Changing the app's language
  /// rebuilds the whole schedule, otherwise the notifications already booked
  /// would keep arriving in the old one.
  Locale? _remindersLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_remindersLocale == locale) return;
    _remindersLocale = locale;

    final l10n = AppLocalizations.of(context)!;
    final strings = ReminderStrings(
      medicationBody: l10n.reminderMedicationBody,
      medicationBodyWithDosage: l10n.reminderMedicationBodyWithDosage(
        '{dosage}',
      ),
      preventionTitle: l10n.reminderPreventionTitle('{productName}'),
      preventionVaccineBody: l10n.reminderPreventionVaccineBody(0)
          .replaceFirst('0', '{days}'),
      preventionMedicationBody: l10n.reminderPreventionMedicationBody,
      channelName: l10n.reminderChannelName,
      channelDescription: l10n.reminderChannelDescription,
    );

    unawaited(_reminderSyncService?.stop() ?? Future<void>.value());
    _reminderSyncService = ReminderSyncService(
      medicationRepository: FirestoreMedicationRepository(),
      preventionProgramRepository: FirestorePreventionProgramRepository(),
      preventionRecordRepository: FirestorePreventionRecordRepository(),
      adapter: ReminderNotificationAdapter(strings: strings),
      preventionScheduler: ReminderScheduler(strings: strings),
      medicationScheduler: MedicationReminderScheduler(strings: strings),
    );
    // The set has not changed, but the service has, so it needs telling.
    _trackedPetIds = const [];
    _onPetsChanged();
  }

  /// Restarts reminder tracking whenever the set of pets changes.
  ///
  /// The whole household, not just the active pet: a reminder for the dog
  /// you are not currently looking at still has to fire.
  void _onPetsChanged() {
    final petIds = (_authController?.pets ?? const <PetProfile>[])
        .map((pet) => pet.petId)
        .toList();
    if (_listEquals(petIds, _trackedPetIds)) return;
    _trackedPetIds = petIds;
    unawaited(
      _reminderSyncService?.start(uid: widget.uid, petIds: petIds) ??
          Future<void>.value(),
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Ads are best-effort from the first line: a failure here must never be
  /// visible to someone using the app.
  Future<void> _prepareAds() => prepareAds(
    initializeSdk: AdManager.initialize,
    premiumStatusChanges: _billingRepository.premiumStatusChanges(),
    currentPremiumStatus: () => _billingRepository.currentPremiumStatus,
    preload: _adGate.preload,
  );

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
    _adManager.dispose();
    _authController?.removeListener(_onPetsChanged);
    unawaited(_reminderSyncService?.stop() ?? Future<void>.value());
    _billingRepository.dispose();
    _dailyRecordTabRequest.dispose();
    _medicalTabRequest.dispose();
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
        onOpenWeight: () => _openSectionTab(1, _dailyRecordTabRequest, 1),
        onOpenToilet: () => _openSectionTab(1, _dailyRecordTabRequest, 2),
        onOpenCertificates: () => _openSectionTab(2, _medicalTabRequest, 3),
      ),
      DailyRecordSection(
        uid: uid,
        petId: petId,
        tabRequest: _dailyRecordTabRequest,
        healthRecordRepository: _healthRecordRepository,
        weightRecordRepository: _weightRecordRepository,
        toiletRecordRepository: _toiletRecordRepository,
        onConsultationSuggested: (suggestion) =>
            _openConsultation(context, prefillRecords: [suggestion.reference]),
      ),
      MedicalHomeScreen(uid: uid, petId: petId, tabRequest: _medicalTabRequest),
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

    // Provided rather than passed down: the five triggers live in form
    // screens three levels below this one, and threading a callback through
    // every section to reach them would mean each of those sections knowing
    // about ads.
    return Provider<AdGate>.value(
      value: _adGate,
      child: _buildScaffold(context, l10n),
    );
  }

  Widget _buildScaffold(BuildContext context, AppLocalizations l10n) {
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
          Column(
            children: [
              // Above every section rather than only Home: a notice about
              // support being away, or the app being down, is not something
              // to hide behind a particular tab. It collapses to nothing
              // when there is no notice or the owner dismissed it.
              AnnouncementBanner(
                repository: _announcementRepository,
                onSeeAll: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AnnouncementsScreen(
                      repository: _announcementRepository,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Navigator(
                  key: _shellNavigatorKey,
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    settings: settings,
                    builder: (routeContext) => IndexedStack(
                      index: _selectedIndex,
                      children: _buildSections(routeContext),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // Labels must fit on ONE line in every language. NavigationDestination
      // renders its label as a bare Text with no maxLines, and the icon is
      // laid out relative to it, so a label that wraps pushes just that
      // destination's icon upward and the row of icons stops lining up
      // (PM report, seen in English where "AI consultation" wrapped). The
      // widget exposes no hook for this, so the only lever is keeping the
      // strings short -- test/app/navigation_bar_layout_test.dart pins it.
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
