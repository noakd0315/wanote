import 'package:flutter/material.dart';

import '../../data/prevention_program_repository.dart';
import '../../domain/models/prevention_program.dart';
import 'prevention_program_form_screen.dart';
import 'prevention_record_list_screen.dart';

/// Spec 5.3 program list ("何をどの頻度で行うか" settings). Tapping a program
/// opens its administration history ([PreventionRecordListScreen]); long-press
/// (via trailing edit icon) opens the program's own edit form.
class PreventionProgramListScreen extends StatelessWidget {
  PreventionProgramListScreen({
    super.key,
    required this.uid,
    required this.petId,
    PreventionProgramRepository? repository,
  }) : repository = repository ?? FirestorePreventionProgramRepository();

  final String uid;
  final String petId;
  final PreventionProgramRepository repository;

  String _typeLabel(PreventionType type) {
    switch (type) {
      case PreventionType.vaccine:
        return 'ワクチン';
      case PreventionType.heartworm:
        return 'フィラリア予防';
      case PreventionType.fleaTick:
        return 'ノミ・ダニ予防';
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
        stream: repository.watchPrograms(uid, petId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final programs = snapshot.data!;
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
                        uid: uid,
                        petId: petId,
                        repository: repository,
                        program: program,
                      ),
                    ),
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PreventionRecordListScreen(
                      uid: uid,
                      petId: petId,
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
              uid: uid,
              petId: petId,
              repository: repository,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
