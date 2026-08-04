// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonNoRecordsYet => 'No records yet';

  @override
  String get commonDateLabel => 'Date';

  @override
  String get commonTimeLabel => 'Time';

  @override
  String get healthRecordDeleteConfirmTitle => 'Delete this record?';

  @override
  String get healthRecordNoCommentPlaceholder => '(No comment)';

  @override
  String get healthRecordFormTitleNew => 'New health record';

  @override
  String get healthRecordFormTitleEdit => 'Edit health record';

  @override
  String get healthRecordDateTimeLabel => 'Recorded at';

  @override
  String get healthRecordTagsSectionLabel => 'Category tags';

  @override
  String get healthRecordPhotosSectionLabel => 'Photos';

  @override
  String healthRecordPhotoCount(int count, int max) {
    return '$count/$max photos';
  }

  @override
  String get healthRecordCommentLabel => 'Comment';

  @override
  String get healthRecordTimelineTitle => 'Health records';

  @override
  String get healthRecordTagSkin => 'Skin';

  @override
  String get healthRecordTagAppetiteLoss => 'Loss of appetite';

  @override
  String get healthRecordTagLowEnergy => 'Low energy';

  @override
  String get healthRecordTagVomiting => 'Vomiting';

  @override
  String get healthRecordTagDiarrhea => 'Diarrhea';

  @override
  String get healthRecordTagOther => 'Other';

  @override
  String get toiletFrequencyChartTitle => 'Toilet frequency';

  @override
  String get toiletUrineLabel => 'Urine';

  @override
  String get toiletStoolLabel => 'Stool';

  @override
  String get toiletRecordStoolFormTitle => 'Record stool';

  @override
  String get toiletHardnessSectionLabel => 'Hardness';

  @override
  String get toiletColorSectionLabel => 'Color';

  @override
  String get toiletPhotoAddLabel => 'Add photo (optional)';

  @override
  String get toiletPhotoChangeLabel => 'Change photo';

  @override
  String get toiletRecordTimelineTitle => 'Toilet records';

  @override
  String get toiletConsultAiButtonLabel => 'Consult AI';

  @override
  String toiletUrineColorSubtitle(String color) {
    return 'Color: $color';
  }

  @override
  String toiletStoolConditionSubtitle(String hardness, String color) {
    return 'Hardness: $hardness / Color: $color';
  }

  @override
  String get toiletRecordUrineDialogTitle => 'Record urine';

  @override
  String get toiletUrineColorShadeLabel => 'Color shade';

  @override
  String get toiletRecordSubmitButtonLabel => 'Record';

  @override
  String get toiletHardnessNormal => 'Normal';

  @override
  String get toiletHardnessSoft => 'Soft';

  @override
  String get toiletHardnessDiarrhea => 'Diarrhea';

  @override
  String get toiletHardnessHard => 'Hard';

  @override
  String get toiletColorNormal => 'Normal';

  @override
  String get toiletColorBloodSuspected => 'Blood suspected';

  @override
  String get toiletColorPale => 'Pale';

  @override
  String get urineColorPale => 'Pale (nearly colorless)';

  @override
  String get urineColorNormal => 'Normal (pale yellow)';

  @override
  String get urineColorDark => 'Dark (concentrated)';

  @override
  String get weightRecordTimelineTitle => 'Weight records';

  @override
  String get weightShowChartTooltip => 'Show chart';

  @override
  String get weightShowTableTooltip => 'Show table';

  @override
  String get weightDuplicateDateDialogTitle =>
      'A record already exists for this date';

  @override
  String get weightDuplicateDateDialogContent =>
      'Overwrite the existing entry, or add this as an additional entry? (See spec 3.4 for how multiple entries on the same day are handled.)';

  @override
  String get weightAddAsNewEntryButtonLabel => 'Add as new entry';

  @override
  String get weightOverwriteButtonLabel => 'Overwrite';

  @override
  String get weightPeriodOneMonth => '1 month';

  @override
  String get weightPeriodThreeMonths => '3 months';

  @override
  String get weightPeriodOneYear => '1 year';

  @override
  String get weightDeltaVsPreviousLabel => 'vs. previous';

  @override
  String get weightDeltaVsOneMonthAgoLabel => 'vs. 1 month ago';

  @override
  String get weightNoRecordsForPeriod => 'No records for this period';

  @override
  String get weightEntryDialogTitle => 'Record weight';

  @override
  String get weightKgFieldLabel => 'Weight (kg)';
}
