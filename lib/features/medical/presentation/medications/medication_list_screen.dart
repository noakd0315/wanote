import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/stream_error_view.dart';
import '../../data/medication_repository.dart';
import '../../data/prevention_program_repository.dart';
import '../../domain/models/medication.dart';
import '../../domain/models/prevention_program.dart';
import '../../data/prevention_record_repository.dart';
import '../prevention/prevention_record_form_screen.dart';
import '../prevention/prevention_record_list_screen.dart';
import 'medication_form_screen.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';
import '../../../../shared/widgets/patterned_background.dart';
import '../widgets/confirm_delete.dart';

/// Spec 5.2 list screen, plus the preventive treatments that are also
/// medication.
///
/// PM request: heartworm and flea/tick treatments *are* medication and
/// belong in the medication history. Nothing is copied to achieve that --
/// they stay preventive care records, owned by that feature, and this screen
/// reads them. One record listed in two places, rather than two records that
/// have to be kept in step.
///
/// `PreventionType.medication` already existed (heartworm and flea_tick were
/// merged into it), so telling which programmes qualify needed no new field
/// and no migration.
class MedicationListScreen extends StatefulWidget {
  MedicationListScreen({
    super.key,
    required this.uid,
    required this.petId,
    MedicationRepository? repository,
    PreventionProgramRepository? preventionProgramRepository,
    PreventionRecordRepository? preventionRecordRepository,
  }) : repository = repository ?? FirestoreMedicationRepository(),
       preventionProgramRepository =
           preventionProgramRepository ??
           FirestorePreventionProgramRepository(),
       preventionRecordRepository =
           preventionRecordRepository ?? FirestorePreventionRecordRepository();

  final String uid;
  final String petId;
  final MedicationRepository repository;
  final PreventionProgramRepository preventionProgramRepository;

  /// Where a dose given today is written. The programme says what and how
  /// often; this holds each administration.
  final PreventionRecordRepository preventionRecordRepository;

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  /// Which medicines the list shows (PM request, 2026-08-21).
  ///
  /// Not a period filter like the visit list: a course of medicine is a span
  /// rather than an event, so "still being given" is the question actually
  /// being asked. Starts at ongoing -- a list opened to check what the dog
  /// is on today should not begin with everything it has ever been on.
  _MedicationFilter _filter = _MedicationFilter.ongoing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.medicationListTitle)),
      body: StreamBuilder<List<Medication>>(
        stream: widget.repository.watchMedications(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return WanoteLoadingIndicator.centered();
          }
          return _buildList(context, l10n, snapshot.data!);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MedicationFormScreen(
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

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<Medication> medications,
  ) {
    return StreamBuilder<List<PreventionProgram>>(
      stream: widget.preventionProgramRepository.watchPrograms(
        widget.uid,
        widget.petId,
      ),
      builder: (context, snapshot) {
        // Preventive care failing must not take the medication list down
        // with it: these rows are an addition to this screen, not its
        // subject. An empty list is the right fallback here, unlike on the
        // preventive screens where the failure has to be shown.
        final programs = (snapshot.data ?? const <PreventionProgram>[])
            .where((p) => p.type == PreventionType.medication && p.active)
            .toList();

        if (medications.isEmpty && programs.isEmpty) {
          return Center(child: Text(l10n.medicationListEmptyMessage));
        }

        final shown = _filter.apply(medications, DateTime.now());
        // The prevention rows are the programmes the dog is currently on, so
        // they belong under "ongoing" and under "all", and nowhere else.
        final showPrograms = _filter != _MedicationFilter.finished;

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              // Centred: the bar is narrower than the screen and sat hard
              // against the left edge (PM, 2026-08-21).
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_MedicationFilter>(
                    segments: [
                      for (final filter in _MedicationFilter.values)
                        ButtonSegment(
                          value: filter,
                          label: Text(filter.label(l10n)),
                        ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _filter = selection.first),
                  ),
                ),
              ),
            ),
            if (shown.isEmpty && !(showPrograms && programs.isNotEmpty))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l10n.filterNoMatchMessage)),
              ),
            for (final medication in shown)
              _buildMedication(context, l10n, medication),
            if (showPrograms && programs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  l10n.medicationListPreventionSectionTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final program in programs)
                _buildProgram(context, l10n, program),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMedication(
    BuildContext context,
    AppLocalizations l10n,
    Medication medication,
  ) {
    return ListTile(
      title: Text(medication.name),
      subtitle: Text(
        medication.isOngoingAt(DateTime.now())
            ? l10n.medicationOngoingLabel
            : l10n.medicationEndDateSubtitle(
                medication.endDate!.toLocal().toString().split(' ').first,
              ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (medication.reminderEnabled)
            const Icon(Icons.notifications_active),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDelete(
                context,
                l10n.medicationDeleteConfirmationMessage,
              )) {
                await widget.repository.delete(
                  widget.uid,
                  widget.petId,
                  medication.medicationId,
                );
              }
            },
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MedicationFormScreen(
            uid: widget.uid,
            petId: widget.petId,
            repository: widget.repository,
            medication: medication,
          ),
        ),
      ),
    );
  }

  Widget _buildProgram(
    BuildContext context,
    AppLocalizations l10n,
    PreventionProgram program,
  ) {
    // Two destinations, because the row means two things (PM request): the
    // name is the programme, the plus is a dose given. Sending both to the
    // same screen made one of the two wrong whichever was chosen.
    //
    // The name opens the administration history, not the programme's edit
    // form. Recording a dose here and then having no way to see it was the
    // PM's report ("薬の記録で予防医学を入力しても、履歴をすぐに見れない",
    // 2026-08-17) -- the history was two levels deep under a different tab.
    // This also matches PreventionProgramListScreen, where tapping the name
    // has always meant "show me this programme's doses". Editing the
    // programme itself stays on the 予防医療 tab, which owns it.
    //
    // No delete here, deliberately. Removing a preventive care programme
    // from a screen that does not own it would take its schedule, its
    // reminders and every dose recorded under it -- so deletion lives on
    // the 予防医療 tab, next to the form that creates them.
    return ListTile(
      leading: const Icon(Icons.vaccines_outlined),
      title: Text(program.productName),
      subtitle: Text(l10n.medicationListPreventionBadge),
      trailing: IconButton(
        icon: const Icon(Icons.add),
        tooltip: l10n.preventionRecordFormAddTitleMedication,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PreventionRecordFormScreen(
              uid: widget.uid,
              petId: widget.petId,
              program: program,
              repository: widget.preventionRecordRepository,
            ),
          ),
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PatternedBackground(
            child: PreventionRecordListScreen(
              uid: widget.uid,
              petId: widget.petId,
              program: program,
              repository: widget.preventionRecordRepository,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which medicines the list shows.
enum _MedicationFilter {
  ongoing,
  finished,
  all;

  String label(AppLocalizations l10n) => switch (this) {
    _MedicationFilter.ongoing => l10n.medicationFilterOngoing,
    _MedicationFilter.finished => l10n.medicationFilterFinished,
    _MedicationFilter.all => l10n.medicationFilterAll,
  };

  /// A course with no end date is ongoing; one whose end date has passed is
  /// finished. An end date still in the future counts as ongoing -- the dog
  /// is on it today, which is what the word means to the owner.
  List<Medication> apply(List<Medication> medications, DateTime now) {
    return switch (this) {
      _MedicationFilter.all => medications,
      _MedicationFilter.ongoing =>
        medications.where((m) => m.isOngoingAt(now)).toList(),
      _MedicationFilter.finished =>
        medications.where((m) => !m.isOngoingAt(now)).toList(),
    };
  }
}
