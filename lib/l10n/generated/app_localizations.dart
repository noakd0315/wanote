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

  /// Heading shown on the sign-in screen in sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Heading shown on the sign-in screen in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccountTitle;

  /// Label for the email text field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for the password text field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Validation error shown when the typed email has no @ character.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailValidationError;

  /// Validation error shown when the typed password is too short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordValidationError;

  /// Link shown below the password field, in sign-in mode only.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordLink;

  /// Label for the optional referral code field, shown in sign-up mode only.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeLabel;

  /// Submit button label in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpButton;

  /// Submit button label in sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// Link that switches the form from sign-up mode to sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get switchToSignInLink;

  /// Link that switches the form from sign-in mode to sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get switchToSignUpLink;

  /// Divider text between the email/password form and the social sign-in buttons.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// Google sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// Apple sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// Title of the forgot-password dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordDialogTitle;

  /// Helper text under the email field in the forgot-password dialog.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a reset link to your registered email address'**
  String get forgotPasswordDialogHelperText;

  /// Generic cancel button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Submit button label in the forgot-password dialog.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendButton;

  /// Snackbar shown after a password reset email is successfully requested.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get passwordResetEmailSent;

  /// Snackbar shown when requesting a password reset email fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to send: {error}'**
  String passwordResetEmailFailed(String error);

  /// Snackbar shown when this device is signed out because a different device claimed the account's single active session.
  ///
  /// In en, this message translates to:
  /// **'You were signed out because your account was signed in on another device.'**
  String get forcedSignOutMessage;

  /// Settings menu item that opens the pet switcher/add-pet screen.
  ///
  /// In en, this message translates to:
  /// **'Switch or add a pet'**
  String get switchPetMenuTitle;

  /// Settings menu item that opens the paywall screen.
  ///
  /// In en, this message translates to:
  /// **'Upgrade your plan'**
  String get upgradePlanMenuTitle;

  /// Subtitle under the upgrade-plan settings menu item.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions & AI consultation tickets'**
  String get upgradePlanMenuSubtitle;

  /// Settings menu item that signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutMenuTitle;

  /// Label for the in-app language switcher (sign-in screen icon button, settings menu item).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTitle;

  /// Subtitle/option shown when no manual language override is set -- the app follows the device's own language setting.
  ///
  /// In en, this message translates to:
  /// **'Follow device setting'**
  String get languageMenuSubtitleSystem;

  /// Title of the language-picker dialog opened from the sign-in screen or settings menu.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get languagePickerTitle;

  /// AppBar title of the paywall/upgrade screen.
  ///
  /// In en, this message translates to:
  /// **'Premium & AI tickets'**
  String get paywallAppBarTitle;

  /// AppBar action button that restores previous purchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchasesButton;

  /// Snackbar shown after a purchase succeeds.
  ///
  /// In en, this message translates to:
  /// **'Purchase complete.'**
  String get purchaseCompleteMessage;

  /// Error message shown when a purchase fails.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed: {error}'**
  String purchaseFailedMessage(String error);

  /// Snackbar shown after restoring purchases succeeds.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get purchasesRestoredMessage;

  /// Error message shown when restoring purchases fails.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailedMessage(String error);

  /// Error message shown when RevenueCat offerings fail to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load offerings: {error}\n\nIf this is a dev/test build, the RevenueCat dashboard may not be configured yet.'**
  String offeringsLoadError(String error);

  /// Message shown when the current RevenueCat offering has no available packages.
  ///
  /// In en, this message translates to:
  /// **'No products are available yet. The RevenueCat dashboard has not been configured with offerings/products.'**
  String get noProductsAvailableMessage;

  /// Product label for the monthly premium subscription package.
  ///
  /// In en, this message translates to:
  /// **'Premium (monthly)'**
  String get premiumMonthlyLabel;

  /// Product label for the yearly premium subscription package.
  ///
  /// In en, this message translates to:
  /// **'Premium (yearly)'**
  String get premiumYearlyLabel;

  /// Product label for the 5-pack AI consultation ticket package.
  ///
  /// In en, this message translates to:
  /// **'AI consultation tickets x5'**
  String get aiTickets5Label;

  /// Product label for the 15-pack AI consultation ticket package.
  ///
  /// In en, this message translates to:
  /// **'AI consultation tickets x15'**
  String get aiTickets15Label;

  /// Heading of the promo/referral code redemption section on the paywall screen.
  ///
  /// In en, this message translates to:
  /// **'Have a promo code?'**
  String get campaignCodeSectionTitle;

  /// Error shown when trying to redeem a campaign code while signed out.
  ///
  /// In en, this message translates to:
  /// **'Please sign in before trying this.'**
  String get campaignCodeSignInRequired;

  /// Success message shown after a campaign code is redeemed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been granted 1 month of Premium. Thank you!'**
  String get campaignCodeRedeemedMessage;

  /// Error shown when a redeemed campaign code doesn't exist.
  ///
  /// In en, this message translates to:
  /// **'This code could not be found.'**
  String get campaignCodeUnknownError;

  /// Error shown when a redeemed campaign code is inactive.
  ///
  /// In en, this message translates to:
  /// **'This code is currently inactive.'**
  String get campaignCodeInactiveError;

  /// Error shown when a redeemed campaign code has hit its redemption cap.
  ///
  /// In en, this message translates to:
  /// **'This code has reached its redemption limit.'**
  String get campaignCodeCapReachedError;

  /// Error shown when the user already redeemed this campaign code.
  ///
  /// In en, this message translates to:
  /// **'This code has already been redeemed.'**
  String get campaignCodeAlreadyRedeemedError;

  /// Error shown when a user tries to redeem their own referral code.
  ///
  /// In en, this message translates to:
  /// **'You can\'t use your own referral code.'**
  String get campaignCodeSelfReferralError;

  /// Hint text of the campaign/referral code text field.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get campaignCodeHintText;

  /// Button label that submits the typed campaign/referral code.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get campaignCodeApplyButton;

  /// Displays the current user's own referral code.
  ///
  /// In en, this message translates to:
  /// **'Your referral code: {code}'**
  String referralCodeDisplay(String code);

  /// Tooltip for the icon button that copies the referral code.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyTooltip;

  /// Snackbar shown after copying the referral code to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied.'**
  String get referralCodeCopiedMessage;

  /// Tab label for the consultation tab inside the AI section.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get aiSectionConsultationTab;

  /// Tab label for the monthly report tab inside the AI section.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get aiSectionReportTab;

  /// Tab label for the health record tab inside the daily record section.
  ///
  /// In en, this message translates to:
  /// **'Health record'**
  String get dailyRecordHealthTab;

  /// Tab label for the weight tab inside the daily record section.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get dailyRecordWeightTab;

  /// Tab label for the toilet tab inside the daily record section.
  ///
  /// In en, this message translates to:
  /// **'Toilet'**
  String get dailyRecordToiletTab;

  /// Home screen shortcut chip label that opens the weight chart.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get homeShortcutWeightLabel;

  /// Home screen shortcut chip label that opens the toilet timeline.
  ///
  /// In en, this message translates to:
  /// **'Toilet'**
  String get homeShortcutToiletLabel;

  /// Home screen shortcut chip label that opens the certificate list.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get homeShortcutCertificatesLabel;

  /// Home screen shortcut chip label that opens the AI consultation screen.
  ///
  /// In en, this message translates to:
  /// **'AI consultation'**
  String get homeShortcutConsultationLabel;

  /// Home screen shortcut chip label that opens the food portion screen.
  ///
  /// In en, this message translates to:
  /// **'Food portion'**
  String get homeShortcutFoodPortionLabel;

  /// Bottom navigation bar label for the home/dashboard tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHomeLabel;

  /// Bottom navigation bar label for the daily record tab.
  ///
  /// In en, this message translates to:
  /// **'Daily record'**
  String get navDailyRecordLabel;

  /// Bottom navigation bar label for the medical tab.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get navMedicalLabel;

  /// Bottom navigation bar label for the AI consultation tab.
  ///
  /// In en, this message translates to:
  /// **'AI consultation'**
  String get navAiConsultationLabel;

  /// Bottom navigation bar label for the settings & billing tab.
  ///
  /// In en, this message translates to:
  /// **'Settings & billing'**
  String get navSettingsLabel;

  /// Snackbar shown when a pending referral code from sign-up is auto-redeemed on app shell startup.
  ///
  /// In en, this message translates to:
  /// **'Applied your referral code and granted 1 month of Premium.'**
  String get referralCodeAppliedMessage;

  /// Bottom sheet option that opens the camera to take a photo.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get imageSourceCameraOption;

  /// Bottom sheet option that opens the photo library picker.
  ///
  /// In en, this message translates to:
  /// **'Choose from photo library'**
  String get imageSourceGalleryOption;

  /// AppBar title on the biometric re-auth gate shown to returning users with biometric login enabled.
  ///
  /// In en, this message translates to:
  /// **'Unlock wanote'**
  String get biometricGateAppBarTitle;

  /// Button that re-triggers the biometric prompt on the biometric gate screen.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get biometricGateUnlockButton;

  /// Message shown on the biometric gate when the biometric scan fails to match.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication did not match.'**
  String get biometricGateMismatchMessage;

  /// Button that retries the biometric prompt after a mismatch.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get biometricGateRetryButton;

  /// Prompt shown on the biometric gate when falling back to password re-entry.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to continue.'**
  String get biometricGatePasswordPrompt;

  /// Button that submits the password re-entry fallback on the biometric gate.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get biometricGateContinueButton;

  /// Error shown on the biometric gate when the re-entered password is wrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Try again.'**
  String get biometricGateIncorrectPasswordError;

  /// Prompt shown on the biometric gate when falling back to provider (Google/Apple) re-authentication.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get biometricGateReauthPrompt;

  /// Error shown on the biometric gate when provider re-authentication fails or is cancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was not completed.'**
  String get biometricGateReauthFailedError;

  /// AppBar title on the post-registration biometric setup screen.
  ///
  /// In en, this message translates to:
  /// **'Biometric login'**
  String get biometricSetupAppBarTitle;

  /// Headline on the biometric setup screen.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric login?'**
  String get biometricSetupHeadline;

  /// Explanatory body text on the biometric setup screen.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID / Touch ID / fingerprint to unlock wanote next time instead of typing your password. Your biometric data itself never leaves this device.'**
  String get biometricSetupDescription;

  /// Button that enables biometric login on the biometric setup screen.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get biometricSetupEnableButton;

  /// Button that skips biometric setup for now.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get biometricSetupSkipButton;

  /// AppBar title on the pet profile form when creating a new pet.
  ///
  /// In en, this message translates to:
  /// **'Add a pet'**
  String get petProfileFormAddTitle;

  /// AppBar title on the pet profile form when editing an existing pet.
  ///
  /// In en, this message translates to:
  /// **'Edit pet'**
  String get petProfileFormEditTitle;

  /// Snackbar shown when the user tries to navigate away from the pet profile form while a save is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving in progress. Please wait.'**
  String get petProfileFormSavingInProgressMessage;

  /// Snackbar shown when the pet profile form is submitted without a birthday selected.
  ///
  /// In en, this message translates to:
  /// **'Please select a birthday'**
  String get petProfileFormBirthdayRequiredMessage;

  /// Label for the pet name text field on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get petProfileFormNameLabel;

  /// Validation error shown when the pet name field is left empty.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get petProfileFormNameRequiredError;

  /// Label for the pet breed text field on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get petProfileFormBreedLabel;

  /// Validation error shown when the pet breed field is left empty.
  ///
  /// In en, this message translates to:
  /// **'Breed is required'**
  String get petProfileFormBreedRequiredError;

  /// Placeholder list-tile title for the birthday picker before a birthday is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select birthday'**
  String get petProfileFormSelectBirthdayLabel;

  /// List-tile title showing the chosen birthday, formatted as yyyy/MM/dd.
  ///
  /// In en, this message translates to:
  /// **'Birthday: {date}'**
  String petProfileFormBirthdayLabel(String date);

  /// Label for the sex dropdown on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get petProfileFormSexLabel;

  /// Dropdown item label for the male option of the pet sex field.
  ///
  /// In en, this message translates to:
  /// **'male'**
  String get petSexOptionMale;

  /// Dropdown item label for the female option of the pet sex field.
  ///
  /// In en, this message translates to:
  /// **'female'**
  String get petSexOptionFemale;

  /// Title of the neutered/spayed switch on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Neutered / spayed'**
  String get petProfileFormNeuteredLabel;

  /// Label for the optional weight text field on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg) - optional'**
  String get petProfileFormWeightLabel;

  /// Validation error shown when the weight field contains non-numeric text.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get petProfileFormWeightValidationError;

  /// Submit button label on the pet profile form when editing an existing pet.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get petProfileFormSaveButton;

  /// Button label for adding a new pet -- used as the pet profile form's submit button in create mode, and as the pet switcher screen's floating action button.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get addPetButton;

  /// Section header above the pet's icon/avatar photo picker on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Icon photo'**
  String get petProfileFormIconSectionTitle;

  /// Button that deletes the pet's icon/avatar photo on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Delete icon photo'**
  String get petProfileFormDeleteIconButton;

  /// Label for the slider that adjusts the icon photo's horizontal crop position.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get petProfileFormIconOffsetXLabel;

  /// Label for the slider that adjusts the icon photo's vertical crop position.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get petProfileFormIconOffsetYLabel;

  /// Label for the slider that adjusts the icon photo's zoom level.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get petProfileFormIconZoomLabel;

  /// Section header above the pet's background photo picker on the pet profile form.
  ///
  /// In en, this message translates to:
  /// **'Background photo (Home screen)'**
  String get petProfileFormBackgroundSectionTitle;

  /// Button that opens the image picker to change the background photo.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get petProfileFormChangeBackgroundButton;

  /// Button that deletes the background photo.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get petProfileFormDeleteBackgroundButton;

  /// AppBar title on the pet switcher screen listing every pet on the account.
  ///
  /// In en, this message translates to:
  /// **'Your pets'**
  String get yourPetsScreenTitle;

  /// Empty-state message on the pet switcher screen when the account has no pets.
  ///
  /// In en, this message translates to:
  /// **'No pets yet. Add your first pet below.'**
  String get noPetsYetMessage;

  /// Title of the confirmation dialog shown when removing a pet.
  ///
  /// In en, this message translates to:
  /// **'Remove pet'**
  String get removePetDialogTitle;

  /// Body of the confirmation dialog shown when removing a pet, naming the pet.
  ///
  /// In en, this message translates to:
  /// **'Remove {petName} from this account?'**
  String removePetDialogContent(String petName);

  /// Cancel button on the remove-pet confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get removePetDialogCancelButton;

  /// Confirm button on the remove-pet confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePetDialogConfirmButton;
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
