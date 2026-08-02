import 'package:flutter/material.dart';

import '../features/daily_record/data/health_record_repository.dart';
import '../features/daily_record/data/toilet_record_repository.dart';
import '../features/daily_record/data/weight_record_repository.dart';
import '../features/daily_record/presentation/health_record_timeline_screen.dart';
import '../features/daily_record/presentation/toilet_record_timeline_screen.dart';
import '../features/daily_record/presentation/weight_record_chart_screen.dart';
import '../shared/models/consultation_reference_record.dart';

/// 日常記録 section of the app shell.
///
/// features/daily_record ships 3 independent screens (photo-attached health
/// records, weight chart, toilet timeline) with no umbrella widget of its
/// own -- per wanote/.claude/CLAUDE.md's directory-ownership rule, that
/// composition belongs at the app-shell level, not inside
/// features/daily_record/. This file is that composition, structured to
/// match `lib/app/../features/medical/presentation/medical_home_screen.dart`'s
/// AppBar+TabBar pattern (previously this used a SegmentedButton, which read
/// as a visually different design from 医療's tabs -- unified per the PM's
/// request).
class DailyRecordSection extends StatelessWidget {
  const DailyRecordSection({
    super.key,
    required this.uid,
    required this.petId,
    required this.healthRecordRepository,
    required this.weightRecordRepository,
    required this.toiletRecordRepository,
    this.onConsultationSuggested,
  });

  final String uid;
  final String petId;
  final HealthRecordRepository healthRecordRepository;
  final WeightRecordRepository weightRecordRepository;
  final ToiletRecordRepository toiletRecordRepository;

  /// Forwarded straight through to [ToiletRecordTimelineScreen] -- see that
  /// widget's doc comment. The app-shell wires this to push the AI
  /// consultation screen with the suggested record pre-filled, since
  /// features/daily_record must not import features/ai itself.
  final void Function(ConsultationSuggestion suggestion)? onConsultationSuggested;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('日常記録'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notes_outlined), text: '健康記録'),
              Tab(icon: Icon(Icons.monitor_weight_outlined), text: '体重'),
              Tab(icon: Icon(Icons.wc_outlined), text: 'トイレ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HealthRecordTimelineScreen(
              uid: uid,
              petId: petId,
              repository: healthRecordRepository,
            ),
            WeightRecordChartScreen(
              uid: uid,
              petId: petId,
              repository: weightRecordRepository,
            ),
            ToiletRecordTimelineScreen(
              uid: uid,
              petId: petId,
              repository: toiletRecordRepository,
              onConsultationSuggested: onConsultationSuggested,
            ),
          ],
        ),
      ),
    );
  }
}
