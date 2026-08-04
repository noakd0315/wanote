import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/prevention_program_repository.dart';
import '../../domain/models/prevention_program.dart';
import 'prevention_program_form_screen.dart';
import 'prevention_record_list_screen.dart';

/// Spec 5.3 program list ("何をどの頻度で行うか" settings). Tapping a program
/// opens its administration history ([PreventionRecordListScreen]); long-press
/// (via trailing edit icon) opens the program's own edit form.
///
/// PM request: 狂犬病ワクチン／混合ワクチン／フィラリア予防／ノミ・ダニ予防
/// の4つをデフォルトで出力したい -- the first time this screen finds zero
/// programs for the pet, it seeds those 4 (name/frequency/enabled all
/// editable afterwards via the existing edit form, same as any other
/// program). Seeding here (not e.g. at pet-creation time in features/auth)
/// keeps this entirely inside features/medical, per CLAUDE.md's
/// each-feature-owns-its-directory rule, and also naturally backfills
/// existing pets that currently have an empty list.
class PreventionProgramListScreen extends StatefulWidget {
  PreventionProgramListScreen({
    super.key,
    required this.uid,
    required this.petId,
    PreventionProgramRepository? repository,
  }) : repository = repository ?? FirestorePreventionProgramRepository();

  final String uid;
  final String petId;
  final PreventionProgramRepository repository;

  @override
  State<PreventionProgramListScreen> createState() =>
      _PreventionProgramListScreenState();
}

class _PreventionProgramListScreenState
    extends State<PreventionProgramListScreen> {
  /// (type, productName, scheduleType) -- standard defaults per common
  /// veterinary guidance (annual rabies/core-vaccine boosters, monthly
  /// heartworm/flea-tick prevention); all editable afterwards. Listed here
  /// (and seeded below) in the PM-requested display order -- 狂犬病>混合
  /// ワクチン>フィラリア予防>ノミ・ダニ予防 -- which the list screen then
  /// preserves by showing programs oldest-created-first (see
  /// PreventionProgramRepository.watchPrograms's ordering).
  static const _defaults = [
    (PreventionType.vaccine, '狂犬病ワクチン', ScheduleType.annual),
    (PreventionType.vaccine, '混合ワクチン', ScheduleType.annual),
    (PreventionType.medication, 'フィラリア予防', ScheduleType.monthly),
    (PreventionType.medication, 'ノミ・ダニ予防', ScheduleType.monthly),
  ];

  bool _seedAttempted = false;

  Future<void> _seedDefaultsIfEmpty(List<PreventionProgram> current) async {
    if (_seedAttempted || current.isNotEmpty) return;
    _seedAttempted = true;
    for (final (type, productName, scheduleType) in _defaults) {
      await widget.repository.create(
        uid: widget.uid,
        petId: widget.petId,
        type: type,
        productName: productName,
        scheduleType: scheduleType,
        active: true,
      );
    }
  }

  String _typeLabel(PreventionType type) {
    switch (type) {
      case PreventionType.vaccine:
        return 'ワクチン';
      case PreventionType.medication:
        return '投薬';
    }
  }

  String _scheduleLabel(PreventionProgram program) {
    switch (program.scheduleType) {
      case ScheduleType.single:
        return '単発';
      case ScheduleType.monthly:
        return '毎月';
      case ScheduleType.annual:
        return '毎年';
      case ScheduleType.custom:
        return '${program.intervalDays}日ごと';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('予防医療プログラム')),
      body: StreamBuilder<List<PreventionProgram>>(
        stream: widget.repository.watchPrograms(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final programs = snapshot.data!;
          if (programs.isEmpty && !_seedAttempted) {
            // Fire-and-forget: the live stream above picks up the newly
            // created docs automatically once seeding completes, so this
            // build just shows the loading state in the meantime.
            unawaited(_seedDefaultsIfEmpty(programs));
            return const Center(child: CircularProgressIndicator());
          }
          if (programs.isEmpty) {
            return const Center(child: Text('予防プログラムがありません'));
          }
          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              return ListTile(
                title: Text(program.productName),
                subtitle: Text(
                  '${_typeLabel(program.type)} ・ ${_scheduleLabel(program)}'
                  '${program.active ? '' : '（無効）'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PreventionProgramFormScreen(
                        uid: widget.uid,
                        petId: widget.petId,
                        repository: widget.repository,
                        program: program,
                      ),
                    ),
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PreventionRecordListScreen(
                      uid: widget.uid,
                      petId: widget.petId,
                      program: program,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PreventionProgramFormScreen(
              uid: widget.uid,
              petId: widget.petId,
              repository: widget.repository,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
