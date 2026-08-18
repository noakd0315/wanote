import 'package:flutter/material.dart';

import '../features/daily_record/data/health_record_repository.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../features/daily_record/presentation/health_record_timeline_screen.dart';
import '../features/daily_record/presentation/toilet_record_timeline_screen.dart';
import '../features/daily_record/presentation/weight_record_chart_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/models/consultation_reference_record.dart';
import '../shared/widgets/keep_alive_tab.dart';

/// 日常記録 section of the app shell.
///
/// features/daily_record ships 3 independent screens (photo-attached health
/// records, weight chart, toilet timeline) with no umbrella widget of its
/// own -- per wanote/.claude/CLAUDE.md's directory-ownership rule, that
/// composition belongs at the app-shell level, not inside
/// features/daily_record/. This file is that composition: a small local
/// segmented control swaps between the three, matching AiSection's exact
/// pattern (no Scaffold/AppBar of its own -- HomeShell's outer AppBar
/// already covers every section, per the PM's request to unify 日常記録/
/// 医療's design with AI相談's).
class DailyRecordSection extends StatefulWidget {
  const DailyRecordSection({
    super.key,
    required this.uid,
    required this.petId,
    required this.healthRecordRepository,
    required this.weightRecordRepository,
    required this.toiletRecordRepository,
    this.onConsultationSuggested,
    this.onConsultAboutRecord,
    this.tabRequest,
  });

  /// Set by HomeShell when a Home shortcut asks for a specific tab.
  /// Null when the section is used on its own.
  final ValueNotifier<int>? tabRequest;

  final String uid;
  final String petId;
  final HealthRecordRepository healthRecordRepository;
  final WeightRecordRepository weightRecordRepository;
  final ToiletRecordRepository toiletRecordRepository;

  /// Forwarded straight through to [ToiletRecordTimelineScreen] -- see that
  /// widget's doc comment. The app-shell wires this to push the AI
  /// consultation screen with the suggested record pre-filled, since
  /// features/daily_record must not import features/ai itself.
  final void Function(ConsultationSuggestion suggestion)?
  onConsultationSuggested;

  /// Forwarded to the toilet detail screen's AI-consultation button.
  final void Function(ConsultationReferenceRecord reference)?
  onConsultAboutRecord;

  @override
  State<DailyRecordSection> createState() => _DailyRecordSectionState();
}

class _DailyRecordSectionState extends State<DailyRecordSection>
    with SingleTickerProviderStateMixin {
  // TabBar (not SegmentedButton) per the PM's request -- the segmented
  // button's icon+label segments could overflow/wrap on narrower widths,
  // which is exactly the "内部メニューが崩れる" breakage being reverted here.
  // The controller only drives the TabBar's own visuals/gestures; actual
  // content switching still goes through IndexedStack (see build below) so
  // each tab keeps its own state across switches, same as before.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    widget.tabRequest?.addListener(_applyTabRequest);
    _applyTabRequest();
  }

  /// Honours a tab a Home shortcut asked for. Applied on init as well as on
  /// change, because the first request can land before this section has ever
  /// been built.
  void _applyTabRequest() {
    final requested = widget.tabRequest?.value;
    if (requested == null || requested == _tabController.index) return;
    if (requested < 0 || requested >= _tabController.length) return;
    _tabController.index = requested;
  }

  @override
  void dispose() {
    widget.tabRequest?.removeListener(_applyTabRequest);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.notes_outlined),
                text: l10n.dailyRecordHealthTab,
              ),
              Tab(
                icon: const Icon(Icons.monitor_weight_outlined),
                text: l10n.dailyRecordWeightTab,
              ),
              Tab(
                icon: const Icon(Icons.wc_outlined),
                text: l10n.dailyRecordToiletTab,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              KeepAliveTab(
                child: HealthRecordTimelineScreen(
                  uid: widget.uid,
                  petId: widget.petId,
                  repository: widget.healthRecordRepository,
                ),
              ),
              KeepAliveTab(
                child: WeightRecordChartScreen(
                  uid: widget.uid,
                  petId: widget.petId,
                  repository: widget.weightRecordRepository,
                ),
              ),
              KeepAliveTab(
                child: ToiletRecordTimelineScreen(
                  healthRecordRepository: widget.healthRecordRepository,
                  uid: widget.uid,
                  petId: widget.petId,
                  repository: widget.toiletRecordRepository,
                  onConsultationSuggested: widget.onConsultationSuggested,
                  onConsultAboutRecord: widget.onConsultAboutRecord,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
