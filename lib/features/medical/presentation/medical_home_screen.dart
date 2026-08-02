import 'package:flutter/material.dart';

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

class _MedicalHomeScreenState extends State<MedicalHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('通院'),
                  icon: Icon(Icons.local_hospital_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('薬'),
                  icon: Icon(Icons.medication_outlined),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('予防医療'),
                  icon: Icon(Icons.vaccines_outlined),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('証明書'),
                  icon: Icon(Icons.description_outlined),
                ),
              ],
              selected: {_selectedIndex},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedIndex = selection.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
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
