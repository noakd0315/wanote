import 'package:flutter/material.dart';

import 'medications/medication_list_screen.dart';
import 'prevention/certificate_list_screen.dart';
import 'prevention/prevention_program_list_screen.dart';
import 'visits/visit_list_screen.dart';

/// Entry point for the medical feature. Spec 5.5: "通院履歴・薬・予防医療は
/// 互いに独立したエンティティとして持たせるが、UI上は「医療情報」としてまとめ
/// て閲覧できるタブを用意する" -- this is that combined tab.
class MedicalHomeScreen extends StatelessWidget {
  const MedicalHomeScreen({super.key, required this.uid, required this.petId});

  final String uid;
  final String petId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('医療情報'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '通院'),
              Tab(text: '薬'),
              Tab(text: '予防医療'),
              Tab(text: '証明書'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VisitListScreen(uid: uid, petId: petId),
            MedicationListScreen(uid: uid, petId: petId),
            PreventionProgramListScreen(uid: uid, petId: petId),
            CertificateListScreen(uid: uid, petId: petId),
          ],
        ),
      ),
    );
  }
}
