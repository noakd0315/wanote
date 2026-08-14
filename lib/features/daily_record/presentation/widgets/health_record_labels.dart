import 'package:flutter/widgets.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../models/health_record.dart';

/// Localized display label for a [HealthRecordTag].
///
/// [HealthRecordTag] lives in the domain/model layer
/// (`models/health_record.dart`) which has no [BuildContext] and therefore
/// cannot call `AppLocalizations.of(context)` itself, so the display-label
/// lookup lives here in the presentation layer instead of on the enum. The
/// enum's own `.wireName` getter is untouched: it's the technical identifier
/// persisted to Firestore, not display text. Shared across
/// [HealthRecordDetailScreen], [HealthRecordFormScreen] and
/// [HealthRecordTimelineScreen], which is why this lives in its own file
/// rather than inline in any one of them.
String healthRecordTagLabel(BuildContext context, HealthRecordTag tag) {
  final l10n = AppLocalizations.of(context)!;
  return switch (tag) {
    HealthRecordTag.skin => l10n.healthRecordTagSkin,
    HealthRecordTag.appetiteLoss => l10n.healthRecordTagAppetiteLoss,
    HealthRecordTag.lowEnergy => l10n.healthRecordTagLowEnergy,
    HealthRecordTag.vomiting => l10n.healthRecordTagVomiting,
    HealthRecordTag.diarrhea => l10n.healthRecordTagDiarrhea,
    HealthRecordTag.bloodyStool => l10n.healthRecordTagBloodyStool,
    HealthRecordTag.other => l10n.healthRecordTagOther,
  };
}
