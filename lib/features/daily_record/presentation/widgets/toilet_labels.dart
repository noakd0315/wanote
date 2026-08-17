import 'package:flutter/widgets.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../models/toilet_record.dart';

/// Localized display labels for [StoolHardness], [StoolColor] and
/// [UrineColor].
///
/// These enums live in the domain/model layer (`models/toilet_record.dart`)
/// which has no [BuildContext] and therefore cannot call
/// `AppLocalizations.of(context)` itself -- so the display-label lookup
/// lives here, in the presentation layer, instead of as a `.label` getter on
/// the enum. The enums' own `.wireName` getter is untouched: it's the
/// technical identifier persisted to Firestore, not display text. Shared by
/// [ToiletRecordFormScreen] and [ToiletRecordTimelineScreen], which is why
/// this lives in its own file rather than inline in either screen.
String stoolHardnessLabel(BuildContext context, StoolHardness hardness) {
  final l10n = AppLocalizations.of(context)!;
  return switch (hardness) {
    StoolHardness.normal => l10n.toiletHardnessNormal,
    StoolHardness.soft => l10n.toiletHardnessSoft,
    StoolHardness.diarrhea => l10n.toiletHardnessDiarrhea,
    StoolHardness.hard => l10n.toiletHardnessHard,
  };
}

String stoolColorLabel(BuildContext context, StoolColor color) {
  final l10n = AppLocalizations.of(context)!;
  return switch (color) {
    StoolColor.normal => l10n.toiletColorNormal,
    StoolColor.bloodSuspected => l10n.toiletColorBloodSuspected,
    StoolColor.pale => l10n.toiletColorPale,
  };
}

String urineColorLabel(BuildContext context, UrineColor color) {
  final l10n = AppLocalizations.of(context)!;
  return switch (color) {
    UrineColor.pale => l10n.urineColorPale,
    UrineColor.normal => l10n.urineColorNormal,
    UrineColor.dark => l10n.urineColorDark,
  };
}

String urineVolumeLabel(BuildContext context, UrineVolume volume) {
  final l10n = AppLocalizations.of(context)!;
  return switch (volume) {
    UrineVolume.small => l10n.urineVolumeSmall,
    UrineVolume.normal => l10n.urineVolumeNormal,
    UrineVolume.large => l10n.urineVolumeLarge,
  };
}
