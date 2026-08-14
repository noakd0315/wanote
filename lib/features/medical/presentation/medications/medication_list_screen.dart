import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/stream_error_view.dart';
import '../../data/medication_repository.dart';
import '../../data/prevention_program_repository.dart';
import '../../domain/models/medication.dart';
import '../../domain/models/prevention_program.dart';
import '../../data/prevention_record_repository.dart';
import '../prevention/prevention_record_form_screen.dart';
import 'medication_form_screen.dart';

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
class MedicationListScreen extends StatelessWidget {
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
           preventionRecordRepository ??
           FirestorePreventionRecordRepository();

  final String uid;
  final String petId;
  final MedicationRepository repository;
  final PreventionProgramRepository preventionProgramRepository;

  /// Where a dose given today is written. The programme says what and how
  /// often; this holds each administration.
  final PreventionRecordRepository preventionRecordRepository;

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
        stream: repository.watchMedications(uid, petId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildList(context, l10n, snapshot.data!);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MedicationFormScreen(
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

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<Medication> medications,
  ) {
    return StreamBuilder<List<PreventionProgram>>(
      stream: preventionProgramRepository.watchPrograms(uid, petId),
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

        return ListView(
          children: [
            for (final medication in medications)
              _buildMedication(context, l10n, medication),
            if (programs.isNotEmpty) ...[
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
    return Dismissible(
      key: ValueKey(medication.medicationId),
      direction: DismissDirection.endToStart,
      background: Container(color: Colors.red),
      onDismissed: (_) =>
          repository.delete(uid, petId, medication.medicationId),
      child: ListTile(
        title: Text(medication.name),
        subtitle: Text(
          medication.isOngoing
              ? l10n.medicationOngoingLabel
              : l10n.medicationEndDateSubtitle(
                  medication.endDate!.toLocal().toString().split(' ').first,
                ),
        ),
        trailing: medication.reminderEnabled
            ? const Icon(Icons.notifications_active)
            : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MedicationFormScreen(
              uid: uid,
              petId: petId,
              repository: repository,
              medication: medication,
            ),
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
    // Opens a new dose, not the programme's settings. This is the
    // medication history: tapping a row here means "I gave this today", and
    // it opened the schedule editor instead (PM report).
    //
    // No Dismissible either, deliberately. Swiping this row away would
    // delete a preventive care programme from a screen that does not own
    // it, taking its schedule and its reminders with it. Deletion stays
    // where the record lives.
    //
    // Reminders keep working untouched: they are driven from the programme
    // by ReminderSyncService, and nothing here changes the programme.
    return ListTile(
      leading: const Icon(Icons.vaccines_outlined),
      title: Text(program.productName),
      subtitle: Text(l10n.medicationListPreventionBadge),
      trailing: const Icon(Icons.add),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PreventionRecordFormScreen(
            uid: uid,
            petId: petId,
            program: program,
            repository: preventionRecordRepository,
          ),
        ),
      ),
    );
  }
}
