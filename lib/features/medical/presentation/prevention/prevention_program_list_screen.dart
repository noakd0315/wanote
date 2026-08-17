import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/prevention_program_repository.dart';
import '../../domain/models/prevention_program.dart';
import '../prevention_type_label.dart';
import 'prevention_program_form_screen.dart';
import 'prevention_record_list_screen.dart';
import '../../../../shared/widgets/stream_error_view.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';

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
  ///
  /// Localized at seed time rather than hardcoded in Japanese: these names
  /// are written to Firestore as ordinary `product_name` data, so whatever
  /// is stored here is what the user sees forever after. Seeding an English
  /// user with Japanese names produced rows like "狂犬病ワクチン / Vaccine ・
  /// Annually" -- half-translated and meaningless to them.
  ///
  /// Being data, an existing pet's names do NOT follow a later language
  /// switch; only pets seeded after the switch pick up the new language.
  /// They stay editable, which is the escape hatch for that.
  List<(PreventionType, String, ScheduleType)> _defaults(
    AppLocalizations l10n,
  ) => [
    (
      PreventionType.vaccine,
      l10n.preventionDefaultProgramRabies,
      ScheduleType.annual,
    ),
    (
      PreventionType.vaccine,
      l10n.preventionDefaultProgramCombinationVaccine,
      ScheduleType.annual,
    ),
    (
      PreventionType.medication,
      l10n.preventionDefaultProgramHeartworm,
      ScheduleType.monthly,
    ),
    (
      PreventionType.medication,
      l10n.preventionDefaultProgramFleaTick,
      ScheduleType.monthly,
    ),
  ];

  bool _seedAttempted = false;

  Future<void> _seedDefaultsIfEmpty(
    AppLocalizations l10n,
    List<PreventionProgram> current,
  ) async {
    if (_seedAttempted || current.isNotEmpty) return;
    _seedAttempted = true;
    for (final (type, productName, scheduleType) in _defaults(l10n)) {
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

  String _scheduleLabel(AppLocalizations l10n, PreventionProgram program) {
    switch (program.scheduleType) {
      case ScheduleType.single:
        return l10n.scheduleTypeSingleBadge;
      case ScheduleType.monthly:
        return l10n.scheduleTypeMonthly;
      case ScheduleType.annual:
        return l10n.scheduleTypeAnnual;
      case ScheduleType.custom:
        return l10n.scheduleIntervalDaysLabel(program.intervalDays!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.preventionProgramListTitle)),
      body: StreamBuilder<List<PreventionProgram>>(
        stream: widget.repository.watchPrograms(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return WanoteLoadingIndicator.centered();
          }
          final programs = snapshot.data!;
          if (programs.isEmpty && !_seedAttempted) {
            // Fire-and-forget: the live stream above picks up the newly
            // created docs automatically once seeding completes, so this
            // build just shows the loading state in the meantime.
            unawaited(_seedDefaultsIfEmpty(l10n, programs));
            return WanoteLoadingIndicator.centered();
          }
          if (programs.isEmpty) {
            return Center(child: Text(l10n.preventionProgramListEmptyMessage));
          }
          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              return ListTile(
                title: Text(program.productName),
                subtitle: Text(
                  '${preventionTypeLabel(l10n, program.type)} ・ '
                  '${_scheduleLabel(l10n, program)}'
                  '${program.active ? '' : l10n.preventionProgramInactiveSuffix}',
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
