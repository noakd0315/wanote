import '../../../l10n/generated/app_localizations.dart';
import '../domain/models/prevention_program.dart';

/// Shared vaccine/medication display label for [PreventionType].
///
/// Used by both the prevention-program form's type dropdown
/// ([PreventionProgramFormScreen]) and the prevention-program list's
/// per-row type badge ([PreventionProgramListScreen]) so the two stay in
/// sync -- see those files for the call sites.
String preventionTypeLabel(AppLocalizations l10n, PreventionType type) {
  switch (type) {
    case PreventionType.vaccine:
      return l10n.preventionTypeVaccine;
    case PreventionType.medication:
      return l10n.preventionTypeMedication;
  }
}
