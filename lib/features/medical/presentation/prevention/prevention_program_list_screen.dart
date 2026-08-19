import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/prevention_program_repository.dart';
import '../../data/prevention_record_repository.dart';
import '../../domain/models/prevention_program.dart';
import '../../domain/models/prevention_record.dart';
import '../prevention_type_label.dart';
import 'prevention_program_form_screen.dart';
import 'prevention_record_list_screen.dart';
import '../../../../shared/utils/formatting.dart';
import '../../../../shared/widgets/stream_error_view.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';
import '../../../../shared/widgets/patterned_background.dart';
import '../widgets/confirm_delete.dart';

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
    PreventionRecordRepository? recordRepository,
  }) : repository = repository ?? FirestorePreventionProgramRepository(),
       recordRepository =
           recordRepository ?? FirestorePreventionRecordRepository();

  final String uid;
  final String petId;
  final PreventionProgramRepository repository;

  /// Read-only here: the list shows each programme's next due date, which
  /// lives on its most recent administration record.
  final PreventionRecordRepository recordRepository;

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

  /// The next due date to show for each programme.
  ///
  /// It lives on the administration records, not on the programme, so the
  /// list has to read both. The most recently administered record wins: an
  /// older one carries an older schedule, and a programme administered
  /// twice would otherwise show whichever date happened to sort first.
  Map<String, DateTime> _nextDueByProgram(List<PreventionRecord> records) {
    final latest = <String, PreventionRecord>{};
    for (final record in records) {
      if (record.nextDueDate == null) continue;
      final current = latest[record.programId];
      if (current == null ||
          record.administeredAt.isAfter(current.administeredAt)) {
        latest[record.programId] = record;
      }
    }
    return {
      for (final entry in latest.entries) entry.key: entry.value.nextDueDate!,
    };
  }

  /// The next-due line under a programme.
  ///
  /// Coloured *and* labelled when the date has passed: colour alone is not
  /// something every reader can act on, and "this is overdue" is the whole
  /// reason the date is worth showing here rather than one tap deeper.
  Widget _nextDueLine(
    BuildContext context,
    AppLocalizations l10n,
    DateTime nextDue,
  ) {
    final now = DateTime.now();
    final overdue = nextDue.isBefore(DateTime(now.year, now.month, now.day));
    return Text(
      '${l10n.preventionNextDueLabel}: ${formatDate(context, nextDue)}'
      '${overdue ? l10n.preventionNextDueOverdueSuffix : ''}',
      style: overdue
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    );
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
          return StreamBuilder<List<PreventionRecord>>(
            stream: widget.recordRepository.watchRecords(
              widget.uid,
              widget.petId,
            ),
            builder: (context, recordSnapshot) {
              // The programmes show straight away and the due dates fill in
              // a moment later. Holding the whole list back for a second
              // stream would make the tab feel slower for one line of
              // secondary information, and an error reading records is not
              // a reason to hide the programmes themselves.
              final nextDueByProgram = _nextDueByProgram(
                recordSnapshot.data ?? const [],
              );
              return ListView.builder(
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  final program = programs[index];
                  final nextDue = nextDueByProgram[program.programId];
                  return ListTile(
                    isThreeLine: nextDue != null,
                    title: Text(program.productName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${preventionTypeLabel(l10n, program.type)} ・ '
                          '${_scheduleLabel(l10n, program)}'
                          '${program.active ? '' : l10n.preventionProgramInactiveSuffix}',
                        ),
                        if (nextDue != null)
                          _nextDueLine(context, l10n, nextDue),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
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
                        // The programme had no delete at all, on any screen --
                        // it could be edited or deactivated and never removed
                        // (PM, 2026-08-18). It belongs here, on the screen that
                        // owns it, and nowhere else.
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirmDelete(
                              context,
                              l10n.preventionProgramDeleteConfirmationMessage,
                            )) {
                              await widget.repository.delete(
                                widget.uid,
                                widget.petId,
                                program.programId,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatternedBackground(
                          child: PreventionRecordListScreen(
                            uid: widget.uid,
                            petId: widget.petId,
                            program: program,
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
