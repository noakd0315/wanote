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
}
