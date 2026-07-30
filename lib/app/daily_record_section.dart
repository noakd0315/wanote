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
/// features/daily_record/. This file is that composition: a small local
/// segmented control swaps between the three, each still fully in charge of
/// its own Scaffold/AppBar/state.
class DailyRecordSection extends StatefulWidget {
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
  State<DailyRecordSection> createState() => _DailyRecordSectionState();
}

class _DailyRecordSectionState extends State<DailyRecordSection> {
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
                  label: Text('健康記録'),
                  icon: Icon(Icons.notes_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('体重'),
                  icon: Icon(Icons.monitor_weight_outlined),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('トイレ'),
                  icon: Icon(Icons.wc_outlined),
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
              HealthRecordTimelineScreen(
                uid: widget.uid,
                petId: widget.petId,
                repository: widget.healthRecordRepository,
              ),
              WeightRecordChartScreen(
                uid: widget.uid,
                petId: widget.petId,
                repository: widget.weightRecordRepository,
              ),
              ToiletRecordTimelineScreen(
                uid: widget.uid,
                petId: widget.petId,
                repository: widget.toiletRecordRepository,
                onConsultationSuggested: widget.onConsultationSuggested,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
