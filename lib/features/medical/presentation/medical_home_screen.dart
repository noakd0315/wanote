import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'medications/medication_list_screen.dart';
import 'prevention/certificate_list_screen.dart';
import 'prevention/prevention_program_list_screen.dart';
import 'visits/visit_list_screen.dart';

/// Entry point for the medical feature. Spec 5.5: "通院履歴・薬・予防医療は
/// 互いに独立したエンティティとして持たせるが、UI上は「医療情報」としてまとめ
/// て閲覧できるタブを用意する" -- this is that combined tab.
///
/// Structured as a segmented-button switcher with no Scaffold/AppBar of its
/// own, matching lib/app/ai_section.dart and lib/app/daily_record_section.dart
/// exactly (the app-shell's outer AppBar already covers every section, per
/// the PM's request to unify these three sections' design on AI相談's).
class MedicalHomeScreen extends StatefulWidget {
  const MedicalHomeScreen({super.key, required this.uid, required this.petId});

  final String uid;
  final String petId;

  @override
  State<MedicalHomeScreen> createState() => _MedicalHomeScreenState();
}

class _MedicalHomeScreenState extends State<MedicalHomeScreen>
    with SingleTickerProviderStateMixin {
  // TabBar (not SegmentedButton) per the PM's request -- the segmented
  // button's icon+label segments could overflow/wrap on narrower widths
  // with 4 segments, which is exactly the "内部メニューが崩れる" breakage
  // being reverted here. Non-scrollable (the TabBar default) so all 4 tabs
  // split the width evenly, matching DailyRecordSection/AiSection's tab
  // bars (PM request: "タブサイズを均等に割り当ててください"). The
  // controller only drives the TabBar's own visuals/gestures; actual
  // content switching still goes through IndexedStack (see build below) so
  // each tab keeps its own state across switches, same as before.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
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
                icon: const Icon(Icons.local_hospital_outlined),
                text: l10n.medicalTabVisits,
              ),
              Tab(
                icon: const Icon(Icons.medication_outlined),
                text: l10n.medicalTabMedications,
              ),
              Tab(
                icon: const Icon(Icons.vaccines_outlined),
                text: l10n.medicalTabPrevention,
              ),
              Tab(
                icon: const Icon(Icons.description_outlined),
                text: l10n.medicalTabCertificates,
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tabController.index,
            children: [
              VisitListScreen(uid: widget.uid, petId: widget.petId),
              MedicationListScreen(uid: widget.uid, petId: widget.petId),
              PreventionProgramListScreen(uid: widget.uid, petId: widget.petId),
              CertificateListScreen(uid: widget.uid, petId: widget.petId),
            ],
          ),
        ),
      ],
    );
  }
}
