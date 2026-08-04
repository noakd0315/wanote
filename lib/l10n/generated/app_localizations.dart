import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// Generic cancel button label used across daily-record dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic save button label used across daily-record forms.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic delete button/action label used across daily-record screens.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Empty-state message shown when a record timeline has no entries.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get commonNoRecordsYet;

  /// Label for a date field/list tile that opens a date picker.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDateLabel;

  /// Label for a time field/list tile that opens a time picker.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get commonTimeLabel;

  /// Title of the confirmation dialog shown before deleting a health record.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get healthRecordDeleteConfirmTitle;

  /// Placeholder shown in the health record detail screen when no memo/comment was entered.
  ///
  /// In en, this message translates to:
  /// **'(No comment)'**
  String get healthRecordNoCommentPlaceholder;

  /// AppBar title of the health record form when creating a new record.
  ///
  /// In en, this message translates to:
  /// **'New health record'**
  String get healthRecordFormTitleNew;

  /// AppBar title of the health record form when editing an existing record.
  ///
  /// In en, this message translates to:
  /// **'Edit health record'**
  String get healthRecordFormTitleEdit;

  /// Label for the recorded-at date/time list tile in the health record form.
  ///
  /// In en, this message translates to:
  /// **'Recorded at'**
  String get healthRecordDateTimeLabel;

  /// Section heading above the category tag chips in the health record form.
  ///
  /// In en, this message translates to:
  /// **'Category tags'**
  String get healthRecordTagsSectionLabel;

  /// Section heading above the photo picker in the health record form.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get healthRecordPhotosSectionLabel;

  /// Shows how many photos are attached out of the maximum allowed, e.g. '2/6 photos'.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max} photos'**
  String healthRecordPhotoCount(int count, int max);

  /// Label for the free-text comment field in the health record form.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get healthRecordCommentLabel;

  /// AppBar title of the health record timeline screen.
  ///
  /// In en, this message translates to:
  /// **'Health records'**
  String get healthRecordTimelineTitle;

  /// Display label for the HealthRecordTag.skin category tag.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get healthRecordTagSkin;

  /// Display label for the HealthRecordTag.appetiteLoss category tag.
  ///
  /// In en, this message translates to:
  /// **'Loss of appetite'**
  String get healthRecordTagAppetiteLoss;

  /// Display label for the HealthRecordTag.lowEnergy category tag.
  ///
  /// In en, this message translates to:
  /// **'Low energy'**
  String get healthRecordTagLowEnergy;

  /// Display label for the HealthRecordTag.vomiting category tag.
  ///
  /// In en, this message translates to:
  /// **'Vomiting'**
  String get healthRecordTagVomiting;

  /// Display label for the HealthRecordTag.diarrhea category tag.
  ///
  /// In en, this message translates to:
  /// **'Diarrhea'**
  String get healthRecordTagDiarrhea;

  /// Display label for the HealthRecordTag.other category tag.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get healthRecordTagOther;

  /// AppBar title of the toilet frequency chart screen.
  ///
  /// In en, this message translates to:
  /// **'Toilet frequency'**
  String get toiletFrequencyChartTitle;

  /// Short label for the urine toilet-record type, used on buttons and the chart legend.
  ///
  /// In en, this message translates to:
  /// **'Urine'**
  String get toiletUrineLabel;

  /// Short label for the stool toilet-record type, used on buttons and the chart legend.
  ///
  /// In en, this message translates to:
  /// **'Stool'**
  String get toiletStoolLabel;

  /// AppBar title of the stool record form.
  ///
  /// In en, this message translates to:
  /// **'Record stool'**
  String get toiletRecordStoolFormTitle;

  /// Section heading above the stool hardness choice chips.
  ///
  /// In en, this message translates to:
  /// **'Hardness'**
  String get toiletHardnessSectionLabel;

  /// Section heading above the stool color choice chips.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get toiletColorSectionLabel;

  /// Button label to attach a photo to a stool record when none is attached yet.
  ///
  /// In en, this message translates to:
  /// **'Add photo (optional)'**
  String get toiletPhotoAddLabel;

  /// Button label to replace the already-attached photo on a stool record.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get toiletPhotoChangeLabel;

  /// AppBar title of the toilet record timeline screen.
  ///
  /// In en, this message translates to:
  /// **'Toilet records'**
  String get toiletRecordTimelineTitle;

  /// Button label on the anomaly-suggestion banner that opens the AI consultation flow.
  ///
  /// In en, this message translates to:
  /// **'Consult AI'**
  String get toiletConsultAiButtonLabel;

  /// Timeline list-tile subtitle for a urine record, showing the recorded color shade.
  ///
  /// In en, this message translates to:
  /// **'Color: {color}'**
  String toiletUrineColorSubtitle(String color);

  /// Timeline list-tile subtitle for a stool record, showing its hardness and color.
  ///
  /// In en, this message translates to:
  /// **'Hardness: {hardness} / Color: {color}'**
  String toiletStoolConditionSubtitle(String hardness, String color);

  /// Title of the dialog used to confirm/edit a one-tap urine record before saving.
  ///
  /// In en, this message translates to:
  /// **'Record urine'**
  String get toiletRecordUrineDialogTitle;

  /// Section heading above the urine color shade choice chips in the urine record dialog.
  ///
  /// In en, this message translates to:
  /// **'Color shade'**
  String get toiletUrineColorShadeLabel;

  /// Submit button label in the urine record dialog.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get toiletRecordSubmitButtonLabel;

  /// Display label for StoolHardness.normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get toiletHardnessNormal;

  /// Display label for StoolHardness.soft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get toiletHardnessSoft;

  /// Display label for StoolHardness.diarrhea.
  ///
  /// In en, this message translates to:
  /// **'Diarrhea'**
  String get toiletHardnessDiarrhea;

  /// Display label for StoolHardness.hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get toiletHardnessHard;

  /// Display label for StoolColor.normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get toiletColorNormal;

  /// Display label for StoolColor.bloodSuspected.
  ///
  /// In en, this message translates to:
  /// **'Blood suspected'**
  String get toiletColorBloodSuspected;

  /// Display label for StoolColor.pale.
  ///
  /// In en, this message translates to:
  /// **'Pale'**
  String get toiletColorPale;

  /// Display label for UrineColor.pale.
  ///
  /// In en, this message translates to:
  /// **'Pale (nearly colorless)'**
  String get urineColorPale;

  /// Display label for UrineColor.normal.
  ///
  /// In en, this message translates to:
  /// **'Normal (pale yellow)'**
  String get urineColorNormal;

  /// Display label for UrineColor.dark.
  ///
  /// In en, this message translates to:
  /// **'Dark (concentrated)'**
  String get urineColorDark;

  /// AppBar title of the weight record chart/table screen.
  ///
  /// In en, this message translates to:
  /// **'Weight records'**
  String get weightRecordTimelineTitle;

  /// Tooltip for the toggle icon button when currently showing the table (tap to switch to chart).
  ///
  /// In en, this message translates to:
  /// **'Show chart'**
  String get weightShowChartTooltip;

  /// Tooltip for the toggle icon button when currently showing the chart (tap to switch to table).
  ///
  /// In en, this message translates to:
  /// **'Show table'**
  String get weightShowTableTooltip;

  /// Title of the dialog shown when adding a weight entry for a date that already has one.
  ///
  /// In en, this message translates to:
  /// **'A record already exists for this date'**
  String get weightDuplicateDateDialogTitle;

  /// Body text of the duplicate-date dialog explaining the overwrite-vs-append choice.
  ///
  /// In en, this message translates to:
  /// **'Overwrite the existing entry, or add this as an additional entry? (See spec 3.4 for how multiple entries on the same day are handled.)'**
  String get weightDuplicateDateDialogContent;

  /// Button label to append a new weight entry alongside an existing same-day one.
  ///
  /// In en, this message translates to:
  /// **'Add as new entry'**
  String get weightAddAsNewEntryButtonLabel;

  /// Button label to overwrite the existing same-day weight entry.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get weightOverwriteButtonLabel;

  /// Segmented button label for the one-month trend period.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get weightPeriodOneMonth;

  /// Segmented button label for the three-month trend period.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get weightPeriodThreeMonths;

  /// Segmented button label for the one-year trend period.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get weightPeriodOneYear;

  /// Label above the weight delta badge comparing against the previous measurement.
  ///
  /// In en, this message translates to:
  /// **'vs. previous'**
  String get weightDeltaVsPreviousLabel;

  /// Label above the weight delta badge comparing against the measurement one month ago.
  ///
  /// In en, this message translates to:
  /// **'vs. 1 month ago'**
  String get weightDeltaVsOneMonthAgoLabel;

  /// Empty-state message when the selected trend period has no weight records.
  ///
  /// In en, this message translates to:
  /// **'No records for this period'**
  String get weightNoRecordsForPeriod;

  /// Title of the dialog used to add a new weight entry.
  ///
  /// In en, this message translates to:
  /// **'Record weight'**
  String get weightEntryDialogTitle;

  /// Label for the numeric weight input field in the weight entry dialog.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKgFieldLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
