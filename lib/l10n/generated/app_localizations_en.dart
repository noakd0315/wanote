// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signInTitle => 'Sign in';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get emailValidationError => 'Enter a valid email address';

  @override
  String get passwordValidationError =>
      'Password must be at least 6 characters';

  @override
  String get forgotPasswordLink => 'Forgot your password?';

  @override
  String get referralCodeLabel => 'Referral code (optional)';

  @override
  String get signUpButton => 'Sign up';

  @override
  String get signInButton => 'Sign in';

  @override
  String get switchToSignInLink => 'Already have an account? Sign in';

  @override
  String get switchToSignUpLink => 'New here? Create an account';

  @override
  String get orDivider => 'or';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get forgotPasswordDialogTitle => 'Reset your password';

  @override
  String get forgotPasswordDialogHelperText =>
      'We\'ll send a reset link to your registered email address';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get sendButton => 'Send';

  @override
  String get passwordResetEmailSent => 'Password reset email sent';

  @override
  String passwordResetEmailFailed(String error) {
    return 'Failed to send: $error';
  }

  @override
  String get forcedSignOutMessage =>
      'You were signed out because your account was signed in on another device.';

  @override
  String get switchPetMenuTitle => 'Switch or add a pet';

  @override
  String get upgradePlanMenuTitle => 'Upgrade your plan';

  @override
  String get upgradePlanMenuSubtitle =>
      'Subscriptions & AI consultation tickets';

  @override
  String get signOutMenuTitle => 'Sign out';

  @override
  String get languageMenuTitle => 'Language';

  @override
  String get languageMenuSubtitleSystem => 'Follow device setting';

  @override
  String get languagePickerTitle => 'Choose language';

  @override
  String get paywallAppBarTitle => 'Premium & AI tickets';

  @override
  String get restorePurchasesButton => 'Restore purchases';

  @override
  String get purchaseCompleteMessage => 'Purchase complete.';

  @override
  String purchaseFailedMessage(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get purchasesRestoredMessage => 'Purchases restored.';

  @override
  String restoreFailedMessage(String error) {
    return 'Restore failed: $error';
  }

  @override
  String offeringsLoadError(String error) {
    return 'Could not load offerings: $error\n\nIf this is a dev/test build, the RevenueCat dashboard may not be configured yet.';
  }

  @override
  String get noProductsAvailableMessage =>
      'No products are available yet. The RevenueCat dashboard has not been configured with offerings/products.';

  @override
  String get premiumMonthlyLabel => 'Premium (monthly)';

  @override
  String get premiumYearlyLabel => 'Premium (yearly)';

  @override
  String get aiTickets5Label => 'AI consultation tickets x5';

  @override
  String get aiTickets15Label => 'AI consultation tickets x15';

  @override
  String get campaignCodeSectionTitle => 'Have a promo code?';

  @override
  String get campaignCodeSignInRequired => 'Please sign in before trying this.';

  @override
  String get campaignCodeRedeemedMessage =>
      'You\'ve been granted 1 month of Premium. Thank you!';

  @override
  String get campaignCodeUnknownError => 'This code could not be found.';

  @override
  String get campaignCodeInactiveError => 'This code is currently inactive.';

  @override
  String get campaignCodeCapReachedError =>
      'This code has reached its redemption limit.';

  @override
  String get campaignCodeAlreadyRedeemedError =>
      'This code has already been redeemed.';

  @override
  String get campaignCodeSelfReferralError =>
      'You can\'t use your own referral code.';

  @override
  String get campaignCodeHintText => 'Enter code';

  @override
  String get campaignCodeApplyButton => 'Apply';

  @override
  String referralCodeDisplay(String code) {
    return 'Your referral code: $code';
  }

  @override
  String get copyTooltip => 'Copy';

  @override
  String get referralCodeCopiedMessage => 'Referral code copied.';

  @override
  String get aiSectionConsultationTab => 'Consultation';

  @override
  String get aiSectionReportTab => 'Report';

  @override
  String get dailyRecordHealthTab => 'Health record';

  @override
  String get dailyRecordWeightTab => 'Weight';

  @override
  String get dailyRecordToiletTab => 'Toilet';

  @override
  String get homeShortcutWeightLabel => 'Weight';

  @override
  String get homeShortcutToiletLabel => 'Toilet';

  @override
  String get homeShortcutCertificatesLabel => 'Certificates';

  @override
  String get homeShortcutConsultationLabel => 'AI consultation';

  @override
  String get homeShortcutFoodPortionLabel => 'Food portion';

  @override
  String get navHomeLabel => 'Home';

  @override
  String get navDailyRecordLabel => 'Daily record';

  @override
  String get navMedicalLabel => 'Medical';

  @override
  String get navAiConsultationLabel => 'AI consultation';

  @override
  String get navSettingsLabel => 'Settings & billing';

  @override
  String get referralCodeAppliedMessage =>
      'Applied your referral code and granted 1 month of Premium.';

  @override
  String get imageSourceCameraOption => 'Take a photo';

  @override
  String get imageSourceGalleryOption => 'Choose from photo library';

  @override
  String get biometricGateAppBarTitle => 'Unlock wanote';

  @override
  String get biometricGateUnlockButton => 'Unlock';

  @override
  String get biometricGateMismatchMessage =>
      'Biometric authentication did not match.';

  @override
  String get biometricGateRetryButton => 'Try again';

  @override
  String get biometricGatePasswordPrompt => 'Enter your password to continue.';

  @override
  String get biometricGateContinueButton => 'Continue';

  @override
  String get biometricGateIncorrectPasswordError =>
      'Incorrect password. Try again.';

  @override
  String get biometricGateReauthPrompt => 'Please sign in again to continue.';

  @override
  String get biometricGateReauthFailedError => 'Sign-in was not completed.';

  @override
  String get biometricSetupAppBarTitle => 'Biometric login';

  @override
  String get biometricSetupHeadline => 'Enable biometric login?';

  @override
  String get biometricSetupDescription =>
      'Use Face ID / Touch ID / fingerprint to unlock wanote next time instead of typing your password. Your biometric data itself never leaves this device.';

  @override
  String get biometricSetupEnableButton => 'Enable';

  @override
  String get biometricSetupSkipButton => 'Not now';

  @override
  String get petProfileFormAddTitle => 'Add a pet';

  @override
  String get petProfileFormEditTitle => 'Edit pet';

  @override
  String get petProfileFormSavingInProgressMessage =>
      'Saving in progress. Please wait.';

  @override
  String get petProfileFormBirthdayRequiredMessage =>
      'Please select a birthday';

  @override
  String get petProfileFormNameLabel => 'Name';

  @override
  String get petProfileFormNameRequiredError => 'Name is required';

  @override
  String get petProfileFormBreedLabel => 'Breed';

  @override
  String get petProfileFormBreedRequiredError => 'Breed is required';

  @override
  String get petProfileFormSelectBirthdayLabel => 'Select birthday';

  @override
  String petProfileFormBirthdayLabel(String date) {
    return 'Birthday: $date';
  }

  @override
  String get petProfileFormSexLabel => 'Sex';

  @override
  String get petSexOptionMale => 'male';

  @override
  String get petSexOptionFemale => 'female';

  @override
  String get petProfileFormNeuteredLabel => 'Neutered / spayed';

  @override
  String get petProfileFormWeightLabel => 'Weight (kg) - optional';

  @override
  String get petProfileFormWeightValidationError => 'Enter a valid number';

  @override
  String get petProfileFormSaveButton => 'Save';

  @override
  String get addPetButton => 'Add pet';

  @override
  String get petProfileFormIconSectionTitle => 'Icon photo';

  @override
  String get petProfileFormDeleteIconButton => 'Delete icon photo';

  @override
  String get petProfileFormIconOffsetXLabel => 'Horizontal';

  @override
  String get petProfileFormIconOffsetYLabel => 'Vertical';

  @override
  String get petProfileFormIconZoomLabel => 'Zoom';

  @override
  String get petProfileFormBackgroundSectionTitle =>
      'Background photo (Home screen)';

  @override
  String get petProfileFormChangeBackgroundButton => 'Change';

  @override
  String get petProfileFormDeleteBackgroundButton => 'Delete';

  @override
  String get yourPetsScreenTitle => 'Your pets';

  @override
  String get noPetsYetMessage => 'No pets yet. Add your first pet below.';

  @override
  String get removePetDialogTitle => 'Remove pet';

  @override
  String removePetDialogContent(String petName) {
    return 'Remove $petName from this account?';
  }

  @override
  String get removePetDialogCancelButton => 'Cancel';

  @override
  String get removePetDialogConfirmButton => 'Remove';

  @override
  String get saveButton => 'Save';

  @override
  String get requiredFieldValidationError => 'This field is required';

  @override
  String get notSetLabel => 'Not set';

  @override
  String get preventionTypeVaccine => 'Vaccine';

  @override
  String get preventionTypeMedication => 'Medication';

  @override
  String get scheduleTypeMonthly => 'Monthly';

  @override
  String get scheduleTypeAnnual => 'Annually';

  @override
  String get medicalTabVisits => 'Visits';

  @override
  String get medicalTabMedications => 'Medications';

  @override
  String get medicalTabPrevention => 'Prevention';

  @override
  String get medicalTabCertificates => 'Certificates';

  @override
  String get medicationFormAddTitle => 'Add medication record';

  @override
  String get medicationFormEditTitle => 'Edit medication record';

  @override
  String get medicationNameLabel => 'Medication name';

  @override
  String get medicationDosageLabel => 'Dosage';

  @override
  String get medicationStartDateLabel => 'Start date';

  @override
  String get medicationOngoingSwitchLabel => 'Ongoing (no end date)';

  @override
  String get medicationEndDateLabel => 'End date';

  @override
  String get medicationReminderSwitchLabel => 'Enable reminder';

  @override
  String get medicationReminderTimeLabel => 'Reminder time';

  @override
  String get medicationListTitle => 'Medications';

  @override
  String get medicationListEmptyMessage => 'No medication records';

  @override
  String get medicationOngoingLabel => 'Ongoing';

  @override
  String medicationEndDateSubtitle(String date) {
    return 'Until $date';
  }

  @override
  String get certificateListTitle => 'Certificates';

  @override
  String get certificateListEmptyTitle => 'No certificates yet';

  @override
  String get certificateListEmptyDescription =>
      'Certificates are captured and saved from the Prevention tab when you add a vaccine, heartworm, or flea/tick prevention record.';

  @override
  String get certificateAddPreventionRecordLabel => 'Add a prevention record';

  @override
  String get preventionProgramFormAddTitle => 'Add prevention program';

  @override
  String get preventionProgramFormEditTitle => 'Edit prevention program';

  @override
  String get preventionTypeFieldLabel => 'Type';

  @override
  String get preventionProductNameLabel => 'Vaccine or medication name';

  @override
  String get scheduleTypeFieldLabel => 'Frequency';

  @override
  String get scheduleTypeSingleOption => 'One-time (register as needed)';

  @override
  String get scheduleTypeCustomOption => 'Custom interval';

  @override
  String get intervalDaysLabel => 'Interval (days)';

  @override
  String get numericValueValidationError => 'Please enter a number';

  @override
  String get preventionProgramActiveSwitchLabel => 'Active';

  @override
  String get preventionProgramListTitle => 'Prevention programs';

  @override
  String get preventionProgramListEmptyMessage => 'No prevention programs';

  @override
  String get scheduleTypeSingleBadge => 'One-time';

  @override
  String scheduleIntervalDaysLabel(int days) {
    return 'Every $days days';
  }

  @override
  String get preventionProgramInactiveSuffix => ' (inactive)';

  @override
  String get savingInProgressMessage => 'Saving, please wait';

  @override
  String get preventionRecordFormAddTitle => 'Add administration record';

  @override
  String get preventionRecordFormEditTitle => 'Edit administration record';

  @override
  String get administeredAtLabel => 'Date administered';

  @override
  String get hospitalNameOptionalLabel =>
      'Veterinary clinic (optional if administered at home)';

  @override
  String get nextDueDateLabel => 'Next due date';

  @override
  String get certificateImageSectionTitle => 'Certificate (image)';

  @override
  String get certificateAlreadyRegisteredMessage =>
      'A certificate is already registered';

  @override
  String get certificateNotRegisteredMessage => 'No certificate registered';

  @override
  String get certificateCaptureManualLabel =>
      'Photograph or choose a certificate (auto-fill coming soon)';

  @override
  String get certificateCaptureAiLabel =>
      'Photograph or choose a certificate for AI auto-fill';

  @override
  String get ocrReadFailedMessage =>
      'Couldn\'t read it automatically. Please enter the details manually';

  @override
  String ocrConfidenceLabel(String percent) {
    return 'AI reading confidence: $percent% (please double-check the details)';
  }

  @override
  String get vaccinationHistoryLabel => 'Vaccination history';

  @override
  String get medicationHistoryLabel => 'Medication history';

  @override
  String get vaccinationRecordLabel => 'vaccination records';

  @override
  String get medicationRecordLabel => 'medication records';

  @override
  String preventionRecordListTitle(String productName, String historyLabel) {
    return '$historyLabel for $productName';
  }

  @override
  String preventionRecordListEmptyMessage(String recordLabel) {
    return 'No $recordLabel found';
  }

  @override
  String nextDueDatePrefixLabel(String date) {
    return 'Next due: $date';
  }

  @override
  String get visitFormAddTitle => 'Add visit record';

  @override
  String get visitFormEditTitle => 'Edit visit record';

  @override
  String get visitedAtLabel => 'Visit date';

  @override
  String get hospitalNameLabel => 'Veterinary clinic';

  @override
  String get diagnosisLabel => 'Diagnosis';

  @override
  String get visitCostLabel => 'Cost (yen)';

  @override
  String get nextVisitDateLabel => 'Next visit date';

  @override
  String get visitListTitle => 'Visit history';

  @override
  String get visitListEmptyMessage => 'No visit records';

  @override
  String get visitFallbackTitle => 'Visit record';

  @override
  String visitCostYenSuffix(int cost) {
    return '¥$cost';
  }

  @override
  String get aiDisclaimerText =>
      'This feature is not a medical diagnosis -- it\'s reference information to help you judge whether a vet visit is needed. If symptoms continue or you\'re concerned, please be sure to see a veterinarian.';

  @override
  String get aiEmergencyMessage =>
      'Please contact or visit a veterinary hospital immediately.\nThis may be a high-urgency situation, so the AI response has been skipped -- we recommend consulting a vet right away.';

  @override
  String get aiUpgradeCardButtonLabel => 'Buy tickets / View premium plans';

  @override
  String get consultationScreenAppBarTitle => 'AI Consultation';

  @override
  String get consultationReferenceRecordsLabel =>
      'Reference related records (optional)';

  @override
  String get consultationInputHintText =>
      'Describe the symptoms or condition you\'re concerned about (e.g. \"lethargic since this morning\")';

  @override
  String get consultationSubmitButton => 'Ask';

  @override
  String get consultationUsageLimitMessage =>
      'You\'ve used up this month\'s free consultations and tickets. Purchase tickets or upgrade to a premium plan to keep using this feature.';

  @override
  String get consultationSubmitFailedMessage =>
      'Failed to send your consultation. Please check your connection and try again.';

  @override
  String get consultationHistoryTitle => 'Consultation history';

  @override
  String get consultationHistoryEmptyMessage => 'No consultation history yet.';

  @override
  String get foodPortionAppBarTitle => 'Calculate food portion';

  @override
  String get foodPortionWeightLabel => 'Weight (kg)';

  @override
  String get foodPortionLifeStageLabel => 'Life stage';

  @override
  String foodPortionNeuteredStatusLabel(String status) {
    return 'Neutered/spayed: $status (from profile)';
  }

  @override
  String get neuteredStatusDone => 'Yes';

  @override
  String get neuteredStatusNotDone => 'No';

  @override
  String get foodPortionBodyConditionLabel => 'Body condition';

  @override
  String get foodPortionBodyConditionHelperText =>
      'Ribs easy to feel = underweight / Feelable but not visible = ideal / Hard to feel = overweight';

  @override
  String get foodPortionActivityLevelLabel => 'Activity level';

  @override
  String get foodPortionPuppyNoteText =>
      '* For growing puppies, the amount is calculated using an age-based factor regardless of body condition or activity level.';

  @override
  String get foodPortionCalorieDensityLabel =>
      'Food calorie density (kcal/100g)';

  @override
  String get foodPortionCalorieDensityHelperText =>
      'Enter the value printed on your food\'s packaging';

  @override
  String get foodPortionCalculateButton => 'Calculate';

  @override
  String get foodPortionRerLabel => 'Resting Energy Requirement (RER)';

  @override
  String get foodPortionMerLabel => 'Maintenance Energy Requirement (MER)';

  @override
  String get foodPortionDailyFoodLabel => 'Daily food amount';

  @override
  String foodPortionKcalPerDayValue(int value) {
    return '$value kcal/day';
  }

  @override
  String foodPortionGramsPerDayValue(int value) {
    return '$value g/day';
  }

  @override
  String get foodPortionResultDisclaimerText =>
      '* This is a guideline. Adjust based on changes in condition or body shape, and consult your veterinarian for details.';

  @override
  String get foodPortionRequestAdviceButton => 'Ask AI for feeding advice';

  @override
  String get foodPortionAdviceUsageLimitMessage =>
      'You\'ve reached your AI consultation usage limit.';

  @override
  String get foodPortionAdviceFailedMessage => 'Failed to get advice.';

  @override
  String get foodPortionAdviceRetryButton => 'Retry';

  @override
  String get dogLifeStagePuppyLabel => 'Puppy (growing)';

  @override
  String get dogLifeStageAdultLabel => 'Adult';

  @override
  String get bodyConditionUnderweightLabel => 'Underweight';

  @override
  String get bodyConditionIdealLabel => 'Ideal';

  @override
  String get bodyConditionOverweightLabel => 'Overweight';

  @override
  String get activityLevelLowLabel => 'Low activity';

  @override
  String get activityLevelNormalLabel => 'Normal';

  @override
  String get activityLevelHighLabel => 'Active';

  @override
  String get reportAppBarTitle => 'AI Health Report';

  @override
  String get reportExportPdfTooltip => 'Export as PDF';

  @override
  String reportPeriodLabel(String start, String end) {
    return 'Period: $start - $end';
  }

  @override
  String get reportWeightTrendTitle => 'Weight trend';

  @override
  String get reportToiletTrendTitle => 'Toilet frequency trend';

  @override
  String get reportAiSummaryTitle => 'AI summary';

  @override
  String get reportGenerationFailedMessage =>
      'Failed to generate the report. Please try again.';

  @override
  String get reportGenerateSummaryButton => 'Generate AI summary';

  @override
  String get reportSummaryUsageLimitMessage =>
      'The AI summary is a premium-only feature. Graphs remain available on the free plan.';

  @override
  String get reportNoWeightDataMessage => 'No weight records.';

  @override
  String get reportNoToiletDataMessage => 'No toilet records.';

  @override
  String get reportUrineLegendLabel => 'Urine';

  @override
  String get reportStoolLegendLabel => 'Stool';
}
