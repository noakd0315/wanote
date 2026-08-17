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

  /// Snackbar shown when requesting a password reset email fails. Deliberately generic -- the underlying SDK error is logged for developers, not shown to the user (PM report: raw SDK error text was showing on screen).
  ///
  /// In en, this message translates to:
  /// **'Failed to send the reset email. Please try again.'**
  String get passwordResetEmailFailed;

  /// Snackbar shown when this device is signed out because a different device claimed the account's single active session.
  ///
  /// In en, this message translates to:
  /// **'You were signed out because your account was signed in on another device.'**
  String get forcedSignOutMessage;

  /// Friendly message for Firebase Auth's 'email-already-in-use' error code, shown when signing up with an email that's already registered.
  ///
  /// In en, this message translates to:
  /// **'This email address is already registered.'**
  String get authErrorEmailAlreadyInUse;

  /// Friendly message for Firebase Auth's 'invalid-email' error code.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorInvalidEmail;

  /// Friendly message for Firebase Auth's 'weak-password' error code.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get authErrorWeakPassword;

  /// Friendly message covering Firebase Auth's 'wrong-password', 'user-not-found', and 'invalid-credential' error codes -- deliberately not distinguishing which one, so a sign-in attempt doesn't reveal whether an email is registered.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorWrongCredentials;

  /// Friendly message for Firebase Auth's 'user-disabled' error code.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Please contact support.'**
  String get authErrorUserDisabled;

  /// Friendly message for Firebase Auth's 'too-many-requests' error code.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get authErrorTooManyRequests;

  /// Friendly message for Firebase Auth's 'network-request-failed' error code.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get authErrorNetworkRequestFailed;

  /// Friendly message for Firebase Auth's 'account-exists-with-different-credential' error code.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email using a different sign-in method.'**
  String get authErrorAccountExistsWithDifferentCredential;

  /// Shown when the provider itself is misconfigured -- retrying fails identically until someone finishes the setup, so the message does not ask for one.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not available yet. Please sign in with your email address.'**
  String get authErrorProviderNotConfigured;

  /// Fallback friendly message for any sign-in/sign-up failure whose error code isn't specifically mapped -- the underlying exception is always logged for developers, never shown on screen.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

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

  /// Error message shown when a purchase fails. Deliberately generic -- the underlying SDK error is logged for developers, not shown to the user (PM report: raw SDK error text was showing on screen).
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get purchaseFailedMessage;

  /// Snackbar shown after restoring purchases succeeds.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get purchasesRestoredMessage;

  /// Error message shown when restoring purchases fails. Deliberately generic -- the underlying SDK error is logged for developers, not shown to the user.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please try again.'**
  String get restoreFailedMessage;

  /// Error message shown when RevenueCat offerings fail to load. Deliberately generic -- the underlying SDK error is logged for developers, not shown to the user.
  ///
  /// In en, this message translates to:
  /// **'Could not load plans. Please check your connection and try again.'**
  String get offeringsLoadError;

  /// Message shown when the current RevenueCat offering has no available packages.
  ///
  /// In en, this message translates to:
  /// **'No plans are available right now. Please try again later.'**
  String get noProductsAvailableMessage;

  /// Message shown on the paywall when the app was built without a RevenueCat API key, so the store cannot be reached at all.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available yet. Please check back soon.'**
  String get billingUnavailableMessage;

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
  /// **'AI chat'**
  String get navAiConsultationLabel;

  /// Bottom navigation bar label for the settings & billing tab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
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

  /// Button on the pet profile form that reopens the pinch-to-frame screen for the icon photo already picked.
  ///
  /// In en, this message translates to:
  /// **'Adjust framing'**
  String get petProfileFormAdjustIconButton;

  /// AppBar title of the pinch-to-frame screen shown after picking a pet icon photo.
  ///
  /// In en, this message translates to:
  /// **'Adjust icon'**
  String get iconCropTitle;

  /// Confirms the framing on the pinch-to-frame screen (used for both the icon and the background photo).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get photoCropConfirmButton;

  /// AppBar title of the pinch-to-frame screen shown after picking a Home background photo.
  ///
  /// In en, this message translates to:
  /// **'Adjust background'**
  String get backgroundCropTitle;

  /// Instruction shown under the background crop frame.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom and drag to position. The area inside the frame is what the Home screen shows.'**
  String get backgroundCropHint;

  /// Button on the pet profile form that reopens the pinch-to-frame screen for the background photo already picked.
  ///
  /// In en, this message translates to:
  /// **'Adjust framing'**
  String get petProfileFormAdjustBackgroundButton;

  /// Instruction shown under the crop circle.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom and drag to position. The area inside the circle becomes the icon.'**
  String get iconCropHint;

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

  /// Generic save button label used across the medical feature's create/edit forms.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// Validation error shown when a required text field is left empty.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredFieldValidationError;

  /// Shown as the subtitle of an optional date field (e.g. end date, next due date) when no date has been picked yet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSetLabel;

  /// Display label for PreventionType.vaccine, used in the prevention program type dropdown and the program list's type badge.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get preventionTypeVaccine;

  /// Display label for PreventionType.medication, used in the prevention program type dropdown and the program list's type badge.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get preventionTypeMedication;

  /// Display label for ScheduleType.monthly, used in the prevention program frequency dropdown and the program list's schedule badge.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get scheduleTypeMonthly;

  /// Display label for ScheduleType.annual, used in the prevention program frequency dropdown and the program list's schedule badge.
  ///
  /// In en, this message translates to:
  /// **'Annually'**
  String get scheduleTypeAnnual;

  /// Tab label for the visit-history tab on the medical home screen.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get medicalTabVisits;

  /// Tab label for the medications tab on the medical home screen.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medicalTabMedications;

  /// Tab label for the prevention-care tab on the medical home screen.
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get medicalTabPrevention;

  /// Tab label for the certificates tab on the medical home screen.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get medicalTabCertificates;

  /// AppBar title of the medication form when adding a new medication.
  ///
  /// In en, this message translates to:
  /// **'Add medication record'**
  String get medicationFormAddTitle;

  /// AppBar title of the medication form when editing an existing medication.
  ///
  /// In en, this message translates to:
  /// **'Edit medication record'**
  String get medicationFormEditTitle;

  /// Label for the medication-name text field.
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get medicationNameLabel;

  /// Label for the dosage text field.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medicationDosageLabel;

  /// ListTile title for the medication start-date picker.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get medicationStartDateLabel;

  /// SwitchListTile title toggling whether the medication is ongoing with no set end date.
  ///
  /// In en, this message translates to:
  /// **'Ongoing (no end date)'**
  String get medicationOngoingSwitchLabel;

  /// ListTile title for the medication end-date picker, shown when the medication is not ongoing.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get medicationEndDateLabel;

  /// SwitchListTile title toggling the medication reminder.
  ///
  /// In en, this message translates to:
  /// **'Enable reminder'**
  String get medicationReminderSwitchLabel;

  /// ListTile title for the medication reminder time picker.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get medicationReminderTimeLabel;

  /// AppBar title of the medication list screen.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medicationListTitle;

  /// Empty-state message shown when the pet has no medication records.
  ///
  /// In en, this message translates to:
  /// **'No medication records'**
  String get medicationListEmptyMessage;

  /// Subtitle shown for a medication list entry that has no end date.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get medicationOngoingLabel;

  /// Subtitle shown for a medication list entry that has an end date.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String medicationEndDateSubtitle(String date);

  /// AppBar title of the certificate list screen.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificateListTitle;

  /// Empty-state title shown when the pet has no registered certificates.
  ///
  /// In en, this message translates to:
  /// **'No certificates yet'**
  String get certificateListEmptyTitle;

  /// Empty-state description explaining how to register a certificate.
  ///
  /// In en, this message translates to:
  /// **'Certificates are captured and saved from the Prevention tab when you add a vaccine, heartworm, or flea/tick prevention record.'**
  String get certificateListEmptyDescription;

  /// Button label and FAB tooltip that navigate from the certificate list to the prevention programs screen.
  ///
  /// In en, this message translates to:
  /// **'Add a prevention record'**
  String get certificateAddPreventionRecordLabel;

  /// AppBar title of the prevention program form when adding a new program.
  ///
  /// In en, this message translates to:
  /// **'Add prevention program'**
  String get preventionProgramFormAddTitle;

  /// AppBar title of the prevention program form when editing an existing program.
  ///
  /// In en, this message translates to:
  /// **'Edit prevention program'**
  String get preventionProgramFormEditTitle;

  /// Label for the prevention program type dropdown (vaccine/medication).
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get preventionTypeFieldLabel;

  /// Label for the product-name text field on the prevention program form.
  ///
  /// In en, this message translates to:
  /// **'Vaccine or medication name'**
  String get preventionProductNameLabel;

  /// Label for the prevention program frequency/schedule dropdown.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get scheduleTypeFieldLabel;

  /// Dropdown option label for ScheduleType.single on the prevention program form.
  ///
  /// In en, this message translates to:
  /// **'One-time (register as needed)'**
  String get scheduleTypeSingleOption;

  /// Dropdown option label for ScheduleType.custom on the prevention program form.
  ///
  /// In en, this message translates to:
  /// **'Custom interval'**
  String get scheduleTypeCustomOption;

  /// Label for the custom interval-days text field, shown when the schedule type is custom.
  ///
  /// In en, this message translates to:
  /// **'Interval (days)'**
  String get intervalDaysLabel;

  /// Validation error shown when the interval-days field isn't a valid number.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number'**
  String get numericValueValidationError;

  /// SwitchListTile title toggling whether the prevention program is active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get preventionProgramActiveSwitchLabel;

  /// AppBar title of the prevention program list screen.
  ///
  /// In en, this message translates to:
  /// **'Prevention programs'**
  String get preventionProgramListTitle;

  /// Empty-state message shown when the pet has no prevention programs.
  ///
  /// In en, this message translates to:
  /// **'No prevention programs'**
  String get preventionProgramListEmptyMessage;

  /// Name given to the rabies program seeded automatically the first time a pet's prevention list is opened. Stored as data on the document, so it keeps whatever language was active at that moment and is freely editable afterwards.
  ///
  /// In en, this message translates to:
  /// **'Rabies vaccine'**
  String get preventionDefaultProgramRabies;

  /// Name given to the core/combination vaccine program seeded automatically for a new pet.
  ///
  /// In en, this message translates to:
  /// **'Combination vaccine'**
  String get preventionDefaultProgramCombinationVaccine;

  /// Name given to the heartworm program seeded automatically for a new pet.
  ///
  /// In en, this message translates to:
  /// **'Heartworm prevention'**
  String get preventionDefaultProgramHeartworm;

  /// Name given to the flea/tick program seeded automatically for a new pet.
  ///
  /// In en, this message translates to:
  /// **'Flea & tick prevention'**
  String get preventionDefaultProgramFleaTick;

  /// Short schedule-type badge text for ScheduleType.single on the prevention program list.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get scheduleTypeSingleBadge;

  /// Short schedule-type badge text for ScheduleType.custom on the prevention program list.
  ///
  /// In en, this message translates to:
  /// **'Every {days} days'**
  String scheduleIntervalDaysLabel(int days);

  /// Suffix appended to a prevention program list entry's subtitle when the program is inactive.
  ///
  /// In en, this message translates to:
  /// **' (inactive)'**
  String get preventionProgramInactiveSuffix;

  /// Snackbar shown when the user tries to leave the prevention record form while a save is still in progress.
  ///
  /// In en, this message translates to:
  /// **'Saving, please wait'**
  String get savingInProgressMessage;

  /// AppBar title of the prevention record form when adding a new record.
  ///
  /// In en, this message translates to:
  /// **'Add administration record'**
  String get preventionRecordFormAddTitle;

  /// AppBar title of the prevention record form when editing an existing record.
  ///
  /// In en, this message translates to:
  /// **'Edit administration record'**
  String get preventionRecordFormEditTitle;

  /// ListTile title for the administered-date picker on the prevention record form.
  ///
  /// In en, this message translates to:
  /// **'Date administered'**
  String get administeredAtLabel;

  /// Label for the hospital-name text field on the prevention record form.
  ///
  /// In en, this message translates to:
  /// **'Veterinary clinic (optional if administered at home)'**
  String get hospitalNameOptionalLabel;

  /// ListTile title for the next-due-date picker on the prevention record form.
  ///
  /// In en, this message translates to:
  /// **'Next due date'**
  String get nextDueDateLabel;

  /// Section heading above the certificate image/capture controls on the prevention record form.
  ///
  /// In en, this message translates to:
  /// **'Certificate (image)'**
  String get certificateImageSectionTitle;

  /// Shown when editing a record that already has a certificate image but none has been newly picked.
  ///
  /// In en, this message translates to:
  /// **'A certificate is already registered'**
  String get certificateAlreadyRegisteredMessage;

  /// Shown in place of the registered certificate when its image fails to load (offline, expired URL, etc.).
  ///
  /// In en, this message translates to:
  /// **'Could not load the certificate image.'**
  String get certificateImageLoadFailedMessage;

  /// Shown when the record has no certificate image at all.
  ///
  /// In en, this message translates to:
  /// **'No certificate registered'**
  String get certificateNotRegisteredMessage;

  /// Button label shown when no OCR backend is configured, so capture is manual-only.
  ///
  /// In en, this message translates to:
  /// **'Photograph or choose a certificate (auto-fill coming soon)'**
  String get certificateCaptureManualLabel;

  /// Button label shown when an OCR backend is configured.
  ///
  /// In en, this message translates to:
  /// **'Photograph or choose a certificate for AI auto-fill'**
  String get certificateCaptureAiLabel;

  /// Shown when the certificate OCR backend returns 429 -- the per-day scan limit is spent. Distinct from a read failure because retrying will not help until tomorrow.
  ///
  /// In en, this message translates to:
  /// **'You have used all of today\'s automatic scans. Please enter the details manually.'**
  String get ocrRateLimitedMessage;

  /// Shown when the certificate OCR backend returns 413. Unlike a read failure, the user can fix this by retaking the photo.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large to scan. Please retake or crop it, or enter the details manually.'**
  String get ocrImageTooLargeMessage;

  /// Shown when the AI-OCR certificate read fails or returns low-confidence results.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read it automatically. Please enter the details manually'**
  String get ocrReadFailedMessage;

  /// Shows the AI-OCR confidence percentage after a successful certificate read.
  ///
  /// In en, this message translates to:
  /// **'AI reading confidence: {percent}% (please double-check the details)'**
  String ocrConfidenceLabel(String percent);

  /// Short label for a vaccine-type prevention program's administration history, used in the record list's title.
  ///
  /// In en, this message translates to:
  /// **'Vaccination history'**
  String get vaccinationHistoryLabel;

  /// Short label for a medication-type prevention program's administration history, used in the record list's title.
  ///
  /// In en, this message translates to:
  /// **'Medication history'**
  String get medicationHistoryLabel;

  /// Lowercase plural noun for vaccine-type prevention records, embedded in the record list's empty-state message.
  ///
  /// In en, this message translates to:
  /// **'vaccination records'**
  String get vaccinationRecordLabel;

  /// Lowercase plural noun for medication-type prevention records, embedded in the record list's empty-state message.
  ///
  /// In en, this message translates to:
  /// **'medication records'**
  String get medicationRecordLabel;

  /// AppBar title of the prevention record list screen, combining the program's product name with its vaccination/medication history label.
  ///
  /// In en, this message translates to:
  /// **'{historyLabel} for {productName}'**
  String preventionRecordListTitle(String productName, String historyLabel);

  /// Empty-state message on the prevention record list screen, combining a generic "no records" phrase with the vaccination/medication record label.
  ///
  /// In en, this message translates to:
  /// **'No {recordLabel} found'**
  String preventionRecordListEmptyMessage(String recordLabel);

  /// Subtitle prefix shown on a prevention record list entry that has a next-due date.
  ///
  /// In en, this message translates to:
  /// **'Next due: {date}'**
  String nextDueDatePrefixLabel(String date);

  /// AppBar title of the visit form when adding a new visit.
  ///
  /// In en, this message translates to:
  /// **'Add visit record'**
  String get visitFormAddTitle;

  /// AppBar title of the visit form when editing an existing visit.
  ///
  /// In en, this message translates to:
  /// **'Edit visit record'**
  String get visitFormEditTitle;

  /// ListTile title for the visit-date picker.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get visitedAtLabel;

  /// Label for the hospital-name text field on the visit form.
  ///
  /// In en, this message translates to:
  /// **'Veterinary clinic'**
  String get hospitalNameLabel;

  /// Label for the diagnosis text field on the visit form.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosisLabel;

  /// Label for the cost text field on the visit form.
  ///
  /// In en, this message translates to:
  /// **'Cost (yen)'**
  String get visitCostLabel;

  /// ListTile title for the next-visit-date picker on the visit form.
  ///
  /// In en, this message translates to:
  /// **'Next visit date'**
  String get nextVisitDateLabel;

  /// AppBar title of the visit list screen.
  ///
  /// In en, this message translates to:
  /// **'Visit history'**
  String get visitListTitle;

  /// Empty-state message shown when the pet has no visit records.
  ///
  /// In en, this message translates to:
  /// **'No visit records'**
  String get visitListEmptyMessage;

  /// Fallback list-tile title for a visit entry that has no hospital name set.
  ///
  /// In en, this message translates to:
  /// **'Visit record'**
  String get visitFallbackTitle;

  /// Trailing cost text on a visit list entry, shown when the visit has a recorded cost.
  ///
  /// In en, this message translates to:
  /// **'¥{cost}'**
  String visitCostYenSuffix(int cost);

  /// Permanent disclaimer shown on every AI response screen (consultation, food portion, report).
  ///
  /// In en, this message translates to:
  /// **'This feature is not a medical diagnosis -- it\'s reference information to help you judge whether a vet visit is needed. If symptoms continue or you\'re concerned, please be sure to see a veterinarian.'**
  String get aiDisclaimerText;

  /// Fixed emergency notice shown instead of an AI response when EmergencyKeywordDetector fires.
  ///
  /// In en, this message translates to:
  /// **'Please contact or visit a veterinary hospital immediately.\nThis may be a high-urgency situation, so the AI response has been skipped -- we recommend consulting a vet right away.'**
  String get aiEmergencyMessage;

  /// Button label on the AI feature's usage-limit upgrade prompt card.
  ///
  /// In en, this message translates to:
  /// **'Buy tickets / View premium plans'**
  String get aiUpgradeCardButtonLabel;

  /// AppBar title of the AI consultation screen.
  ///
  /// In en, this message translates to:
  /// **'AI Consultation'**
  String get consultationScreenAppBarTitle;

  /// Heading above the chip list of prefilled records the user can attach to their consultation.
  ///
  /// In en, this message translates to:
  /// **'Reference related records (optional)'**
  String get consultationReferenceRecordsLabel;

  /// Hint text in the consultation question text field.
  ///
  /// In en, this message translates to:
  /// **'Describe the symptoms or condition you\'re concerned about (e.g. \"lethargic since this morning\")'**
  String get consultationInputHintText;

  /// Button that submits the consultation question.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get consultationSubmitButton;

  /// Message on the upgrade prompt card shown when the user has no consultations left.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used up this month\'s free consultations and tickets. Purchase tickets or upgrade to a premium plan to keep using this feature.'**
  String get consultationUsageLimitMessage;

  /// Error message shown when submitting a consultation fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to send your consultation. Please check your connection and try again.'**
  String get consultationSubmitFailedMessage;

  /// Heading above the consultation history list.
  ///
  /// In en, this message translates to:
  /// **'Consultation history'**
  String get consultationHistoryTitle;

  /// Empty-state message shown when the pet has no past consultations.
  ///
  /// In en, this message translates to:
  /// **'No consultation history yet.'**
  String get consultationHistoryEmptyMessage;

  /// AppBar title of the food portion calculator screen.
  ///
  /// In en, this message translates to:
  /// **'Calculate food portion'**
  String get foodPortionAppBarTitle;

  /// Label for the weight text field on the food portion screen.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get foodPortionWeightLabel;

  /// Label for the life stage dropdown on the food portion screen.
  ///
  /// In en, this message translates to:
  /// **'Life stage'**
  String get foodPortionLifeStageLabel;

  /// Read-only note showing the pet's neutered status as recorded on its profile.
  ///
  /// In en, this message translates to:
  /// **'Neutered/spayed: {status} (from profile)'**
  String foodPortionNeuteredStatusLabel(String status);

  /// Status value meaning the pet is neutered/spayed, embedded in foodPortionNeuteredStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get neuteredStatusDone;

  /// Status value meaning the pet is not neutered/spayed, embedded in foodPortionNeuteredStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get neuteredStatusNotDone;

  /// Label for the body condition dropdown on the food portion screen.
  ///
  /// In en, this message translates to:
  /// **'Body condition'**
  String get foodPortionBodyConditionLabel;

  /// Helper text explaining how to judge body condition.
  ///
  /// In en, this message translates to:
  /// **'Ribs easy to feel = underweight / Feelable but not visible = ideal / Hard to feel = overweight'**
  String get foodPortionBodyConditionHelperText;

  /// Label for the activity level dropdown on the food portion screen.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get foodPortionActivityLevelLabel;

  /// Note shown instead of the body condition/activity level dropdowns when the life stage is puppy.
  ///
  /// In en, this message translates to:
  /// **'* For growing puppies, the amount is calculated using an age-based factor regardless of body condition or activity level.'**
  String get foodPortionPuppyNoteText;

  /// Label for the food calorie density text field.
  ///
  /// In en, this message translates to:
  /// **'Food calorie density (kcal/100g)'**
  String get foodPortionCalorieDensityLabel;

  /// Helper text under the food calorie density field.
  ///
  /// In en, this message translates to:
  /// **'Enter the value printed on your food\'s packaging'**
  String get foodPortionCalorieDensityHelperText;

  /// Button that runs the food portion calculation.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get foodPortionCalculateButton;

  /// Result row label for the resting energy requirement.
  ///
  /// In en, this message translates to:
  /// **'Resting Energy Requirement (RER)'**
  String get foodPortionRerLabel;

  /// Result row label for the daily maintenance energy requirement.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Energy Requirement (MER)'**
  String get foodPortionMerLabel;

  /// Result row label for the recommended daily food amount in grams.
  ///
  /// In en, this message translates to:
  /// **'Daily food amount'**
  String get foodPortionDailyFoodLabel;

  /// Formatted kcal-per-day value shown in the RER/MER result rows.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal/day'**
  String foodPortionKcalPerDayValue(int value);

  /// Formatted grams-per-day value shown in the daily food amount result row.
  ///
  /// In en, this message translates to:
  /// **'{value} g/day'**
  String foodPortionGramsPerDayValue(int value);

  /// Disclaimer shown below the calculation result.
  ///
  /// In en, this message translates to:
  /// **'* This is a guideline. Adjust based on changes in condition or body shape, and consult your veterinarian for details.'**
  String get foodPortionResultDisclaimerText;

  /// Button that requests AI-generated feeding advice based on the calculated result.
  ///
  /// In en, this message translates to:
  /// **'Ask AI for feeding advice'**
  String get foodPortionRequestAdviceButton;

  /// Message on the upgrade prompt card shown when the user has no AI advice requests left.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI consultation usage limit.'**
  String get foodPortionAdviceUsageLimitMessage;

  /// Error message shown when requesting AI feeding advice fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to get advice.'**
  String get foodPortionAdviceFailedMessage;

  /// Button that retries a failed AI feeding advice request.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get foodPortionAdviceRetryButton;

  /// Display label for DogLifeStage.puppy, used in the food portion screen's life stage dropdown.
  ///
  /// In en, this message translates to:
  /// **'Puppy (growing)'**
  String get dogLifeStagePuppyLabel;

  /// Display label for DogLifeStage.adult, used in the food portion screen's life stage dropdown.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get dogLifeStageAdultLabel;

  /// Display label for BodyCondition.underweight, used in the food portion screen's body condition dropdown.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get bodyConditionUnderweightLabel;

  /// Display label for BodyCondition.ideal, used in the food portion screen's body condition dropdown.
  ///
  /// In en, this message translates to:
  /// **'Ideal'**
  String get bodyConditionIdealLabel;

  /// Display label for BodyCondition.overweight, used in the food portion screen's body condition dropdown.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get bodyConditionOverweightLabel;

  /// Display label for ActivityLevel.low, used in the food portion screen's activity level dropdown.
  ///
  /// In en, this message translates to:
  /// **'Low activity'**
  String get activityLevelLowLabel;

  /// Display label for ActivityLevel.normal, used in the food portion screen's activity level dropdown.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get activityLevelNormalLabel;

  /// Display label for ActivityLevel.high, used in the food portion screen's activity level dropdown.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activityLevelHighLabel;

  /// AppBar title of the AI health report screen.
  ///
  /// In en, this message translates to:
  /// **'AI Health Report'**
  String get reportAppBarTitle;

  /// Tooltip for the AppBar action that exports the report as a PDF.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get reportExportPdfTooltip;

  /// Shows the report's date range, each already formatted as yyyy/MM/dd.
  ///
  /// In en, this message translates to:
  /// **'Period: {start} - {end}'**
  String reportPeriodLabel(String start, String end);

  /// Heading above the weight trend chart.
  ///
  /// In en, this message translates to:
  /// **'Weight trend'**
  String get reportWeightTrendTitle;

  /// Heading above the toilet frequency chart.
  ///
  /// In en, this message translates to:
  /// **'Toilet frequency trend'**
  String get reportToiletTrendTitle;

  /// Heading above the AI summary section.
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get reportAiSummaryTitle;

  /// Error message shown when generating the AI summary fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate the report. Please try again.'**
  String get reportGenerationFailedMessage;

  /// Button that triggers AI summary generation.
  ///
  /// In en, this message translates to:
  /// **'Generate AI summary'**
  String get reportGenerateSummaryButton;

  /// Message on the upgrade prompt card shown when the user isn't subscribed to premium.
  ///
  /// In en, this message translates to:
  /// **'The AI summary is a premium-only feature. Graphs remain available on the free plan.'**
  String get reportSummaryUsageLimitMessage;

  /// Empty-state message shown in place of the weight chart when there is no weight data.
  ///
  /// In en, this message translates to:
  /// **'No weight records.'**
  String get reportNoWeightDataMessage;

  /// Empty-state message shown in place of the toilet chart when there is no toilet data.
  ///
  /// In en, this message translates to:
  /// **'No toilet records.'**
  String get reportNoToiletDataMessage;

  /// Legend label for the urine bar in the toilet frequency chart.
  ///
  /// In en, this message translates to:
  /// **'Urine'**
  String get reportUrineLegendLabel;

  /// Legend label for the stool bar in the toilet frequency chart.
  ///
  /// In en, this message translates to:
  /// **'Stool'**
  String get reportStoolLegendLabel;

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
  /// **'Record how they are'**
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

  /// Label for the optional free-text location field on the stool record form and the urine record dialog.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get toiletLocationOptionalLabel;

  /// Timeline list-tile subtitle segment showing the recorded location, appended after the color/condition segment when present.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String toiletLocationSubtitle(String location);

  /// Tooltip on the button that swaps the toilet record list for the frequency chart, in place.
  ///
  /// In en, this message translates to:
  /// **'Show chart'**
  String get toiletShowChartTooltip;

  /// Tooltip on the button that swaps the toilet frequency chart back for the record list.
  ///
  /// In en, this message translates to:
  /// **'Show records'**
  String get toiletShowTimelineTooltip;

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
  String get toiletRecordUrineFormTitle;

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

  /// Button on a new-record form that copies the content of an earlier record.
  ///
  /// In en, this message translates to:
  /// **'Fill from a past record'**
  String get historyCopyButtonLabel;

  /// Title of the sheet listing recent records to copy from.
  ///
  /// In en, this message translates to:
  /// **'Pick a record to copy'**
  String get historyCopyPickerTitle;

  /// Shown in the copy sheet when the pet has no earlier records.
  ///
  /// In en, this message translates to:
  /// **'There are no records to copy yet.'**
  String get historyCopyPickerEmptyMessage;

  /// Confirmation after copying, making clear the date was deliberately not copied.
  ///
  /// In en, this message translates to:
  /// **'Copied. The date is still today\'s.'**
  String get historyCopyAppliedMessage;

  /// Short mark beside a field the certificate OCR filled in, meaning the value has not been confirmed by a person yet.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get ocrNeedsReviewLabel;

  /// Helper text under a text field the certificate OCR filled in.
  ///
  /// In en, this message translates to:
  /// **'Check this: read from the certificate'**
  String get ocrNeedsReviewHelper;

  /// Turns off the latest-per-programme filter on the certificate list.
  ///
  /// In en, this message translates to:
  /// **'Show older certificates'**
  String get certificateShowAllTooltip;

  /// Turns the latest-per-programme filter back on.
  ///
  /// In en, this message translates to:
  /// **'Show latest only'**
  String get certificateShowLatestOnlyTooltip;

  /// Tells the reader how many superseded certificates the filter is holding back.
  ///
  /// In en, this message translates to:
  /// **'{count} older certificates hidden'**
  String certificateOlderHiddenLabel(int count);

  /// Remaining-usage badge on the AI screens while free allowance is left.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {quota} free uses left this month'**
  String aiUsageFreeRemainingLabel(int remaining, int quota);

  /// Remaining-usage badge when the owner holds tickets. Shows both counts, since free allowance is always spent first and the tickets would otherwise look missing until it ran out.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {quota} free uses left this month · {tickets} tickets'**
  String aiUsageFreeAndTicketsLabel(int remaining, int quota, int tickets);

  /// Remaining-usage badge for a subscriber, who has no count to show.
  ///
  /// In en, this message translates to:
  /// **'Unlimited plan'**
  String get aiUsageUnlimitedLabel;

  /// Remaining-usage badge when nothing is left to spend.
  ///
  /// In en, this message translates to:
  /// **'None left (a ticket or plan is needed)'**
  String get aiUsageNoneRemainingLabel;

  /// Section heading above the three body-measurement fields on the pet form.
  ///
  /// In en, this message translates to:
  /// **'Measurements (optional)'**
  String get petProfileFormMeasurementsHeading;

  /// Sub-heading explaining why the measurements are collected.
  ///
  /// In en, this message translates to:
  /// **'Used when picking clothing or a harness.'**
  String get petProfileFormMeasurementsHint;

  /// Button that opens the measuring diagram.
  ///
  /// In en, this message translates to:
  /// **'How to measure'**
  String get petProfileFormMeasurementGuideButton;

  /// Title of the measuring-guide bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'How to measure'**
  String get petProfileFormMeasurementGuideTitle;

  /// Label for the neck measurement. 'Neck girth' is the term used on dog apparel and harness sizing charts.
  ///
  /// In en, this message translates to:
  /// **'Neck girth'**
  String get petProfileFormNeckGirthLabel;

  /// Instruction for measuring neck girth, shown beside callout 1 in the diagram.
  ///
  /// In en, this message translates to:
  /// **'Around the neck where the collar sits, leaving room for one or two fingers.'**
  String get petProfileFormNeckGirthHelp;

  /// Label for the chest measurement. 'Chest girth' is the sizing-chart term; it is the ribcage circumference, not body length.
  ///
  /// In en, this message translates to:
  /// **'Chest girth'**
  String get petProfileFormChestGirthLabel;

  /// Instruction for measuring chest girth, shown beside callout 2 in the diagram.
  ///
  /// In en, this message translates to:
  /// **'Around the widest part of the chest, just behind the front legs.'**
  String get petProfileFormChestGirthHelp;

  /// Label for the back measurement. 'Back length' is the sizing-chart term for the topline.
  ///
  /// In en, this message translates to:
  /// **'Back length'**
  String get petProfileFormBackLengthLabel;

  /// Instruction for measuring back length, shown beside callout 3 in the diagram.
  ///
  /// In en, this message translates to:
  /// **'Along the back, from the base of the neck to the base of the tail.'**
  String get petProfileFormBackLengthHelp;

  /// Validation message when a measurement field holds something that is not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get petProfileFormMeasurementValidationError;

  /// Section heading above the urine volume choice chips.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get toiletUrineVolumeLabel;

  /// Timeline row subtitle fragment for a urine record's volume.
  ///
  /// In en, this message translates to:
  /// **'Amount: {volume}'**
  String toiletUrineVolumeSubtitle(String volume);

  /// AppBar title of the toilet detail screen for a urine record.
  ///
  /// In en, this message translates to:
  /// **'Urination details'**
  String get toiletUrineDetailTitle;

  /// Timeline period filter: the last week.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get toiletPeriodOneWeek;

  /// Timeline period filter: the last month.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get toiletPeriodOneMonth;

  /// Timeline period filter: the last three months.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get toiletPeriodThreeMonths;

  /// Timeline period filter: every record.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get toiletPeriodAll;

  /// Display label for UrineVolume.small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get urineVolumeSmall;

  /// Display label for UrineVolume.normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get urineVolumeNormal;

  /// Display label for UrineVolume.large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get urineVolumeLarge;

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

  /// Label of the 6-month option in the weight chart period toggle.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get weightPeriodSixMonths;

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

  /// Segmented button label for showing every weight record, from the first one onwards.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get weightPeriodAll;

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

  /// Settings menu item that opens the account deletion screen. Required in-app by App Store Review Guideline 5.1.1(v) and Google Play's data deletion policy.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountMenuTitle;

  /// Heading of the warning panel on the account deletion screen.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone'**
  String get deleteAccountWarningTitle;

  /// Lead-in above the list of what account deletion removes.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account permanently removes all of the following. None of it can be recovered.'**
  String get deleteAccountWarningBody;

  /// Bullet in the account deletion warning list.
  ///
  /// In en, this message translates to:
  /// **'Every pet profile you have registered'**
  String get deleteAccountWarningItemPets;

  /// Bullet in the account deletion warning list.
  ///
  /// In en, this message translates to:
  /// **'Health, weight, toilet, vet visit, medication and prevention records'**
  String get deleteAccountWarningItemRecords;

  /// Bullet in the account deletion warning list.
  ///
  /// In en, this message translates to:
  /// **'Every photo and certificate scan you have uploaded'**
  String get deleteAccountWarningItemPhotos;

  /// Bullet in the account deletion warning list.
  ///
  /// In en, this message translates to:
  /// **'Your AI consultation and AI report history'**
  String get deleteAccountWarningItemAi;

  /// Heading of the subscription warning on the account deletion screen. Subscriptions are held by the App Store / Google Play, not by this app, so deleting the account does not stop the billing -- users must be told this before they delete.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is not cancelled automatically'**
  String get deleteAccountSubscriptionNoticeTitle;

  /// Body of the subscription warning on the account deletion screen.
  ///
  /// In en, this message translates to:
  /// **'If you have a premium plan, cancel it yourself in the App Store or Google Play. Deleting your account here does not stop the billing.'**
  String get deleteAccountSubscriptionNoticeBody;

  /// Label of the password field shown to email/password accounts before deletion.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get deleteAccountPasswordFieldLabel;

  /// Helper text under the reauthentication password field.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm it is you.'**
  String get deleteAccountPasswordHelperText;

  /// Shown instead of the password field for Google/Apple accounts, which reauthenticate by redoing their provider sign-in.
  ///
  /// In en, this message translates to:
  /// **'You will be asked to sign in again before your account is deleted.'**
  String get deleteAccountProviderReauthNotice;

  /// Destructive button that opens the final confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountButtonLabel;

  /// Title of the final confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmDialogTitle;

  /// Body of the final confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'All of your data will be permanently deleted and cannot be restored.'**
  String get deleteAccountConfirmDialogContent;

  /// Confirming action in the final confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountConfirmButtonLabel;

  /// Dismissing action in the final confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteAccountCancelButtonLabel;

  /// Shown while deletion runs. Deletion is several sequential steps, so closing the app part-way leaves data behind -- the user has to be asked to wait.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account. Please keep the app open.'**
  String get deleteAccountProgressMessage;

  /// Snackbar shown after deletion succeeds.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get deleteAccountCompletedMessage;

  /// Generic failure message. Deletion is idempotent, so retrying is always the right advice.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed. Check your connection and try again.'**
  String get deleteAccountFailedMessage;

  /// Message for Firebase Auth's 'requires-recent-login' error code during deletion.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again, then retry.'**
  String get deleteAccountRequiresRecentLoginMessage;

  /// Settings menu item, and AppBar title, for the list of in-app notices.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcementsMenuTitle;

  /// Tooltip on the close button of the announcement banner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get announcementDismissTooltip;

  /// Action on the announcement banner that opens the full list.
  ///
  /// In en, this message translates to:
  /// **'All announcements'**
  String get announcementSeeAllButton;

  /// Shown when no notice is currently published.
  ///
  /// In en, this message translates to:
  /// **'There are no announcements right now.'**
  String get announcementsEmpty;

  /// Shown when the announcements query fails. Deliberately not shown on the home banner, which stays silent rather than nagging about its own failure.
  ///
  /// In en, this message translates to:
  /// **'Announcements could not be loaded.'**
  String get announcementsLoadFailed;

  /// Shown when a Firestore list query fails. Replaces an indefinite spinner: PM report -- the prevention record history sat loading forever, because the only branch was 'no data yet' and a failed stream never has data.
  ///
  /// In en, this message translates to:
  /// **'Could not load this list.'**
  String get listLoadFailedMessage;

  /// Rebuilds the list screen so the query is attempted again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get listLoadFailedRetryButton;

  /// Empties the question field and the answer. PM report: the last question and its answer stayed on screen after asking, so the next visit opened onto stale content.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get consultationClearButton;

  /// Title of the dialog showing a stored consultation in full.
  ///
  /// In en, this message translates to:
  /// **'Past consultation'**
  String get consultationHistoryDetailTitle;

  /// Section label above the stored question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get consultationHistoryQuestionLabel;

  /// Section label above the stored answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get consultationHistoryAnswerLabel;

  /// Dismisses a dialog that only shows information, where there is nothing to cancel.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Display label for the HealthRecordTag.bloodyStool category tag.
  ///
  /// In en, this message translates to:
  /// **'Blood in stool'**
  String get healthRecordTagBloodyStool;

  /// Toggle on the stool form. Off by default: the owner decides whether a bowel movement is worth a daily-log entry, rather than the app deciding for them.
  ///
  /// In en, this message translates to:
  /// **'Also add to the daily log'**
  String get toiletCopyToDailyLogLabel;

  /// Explains what the copy does, and that the photo is not duplicated.
  ///
  /// In en, this message translates to:
  /// **'Copies the details as a daily record. The photo stays with this record.'**
  String get toiletCopyToDailyLogDescription;

  /// App bar title of the stool detail screen, which is the only place its photo can be seen.
  ///
  /// In en, this message translates to:
  /// **'Stool record'**
  String get toiletStoolDetailTitle;

  /// The stool record itself was written; only the copy failed. Says both, so the owner does not re-enter a record that already exists.
  ///
  /// In en, this message translates to:
  /// **'Saved, but could not add it to the daily log.'**
  String get toiletCopyToDailyLogFailedMessage;

  /// Memo written onto the copied daily record, so the entry says what it came from.
  ///
  /// In en, this message translates to:
  /// **'Stool: {hardness} / {color}'**
  String toiletStoolCopyMemo(String hardness, String color);

  /// Confirmation before deleting a stool record. Says the photo goes too, because the detail screen is the only place it was ever visible.
  ///
  /// In en, this message translates to:
  /// **'Delete this record? The photo is deleted with it.'**
  String get toiletStoolDeleteConfirmationMessage;

  /// Confirms deletion of a stool record.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get toiletStoolDeleteButton;

  /// Heading above preventive programmes shown on the medication list. PM: heartworm and flea/tick treatments are medication and belong in the medication history, but they are still owned by preventive care -- one record, listed in both places.
  ///
  /// In en, this message translates to:
  /// **'From preventive care'**
  String get medicationListPreventionSectionTitle;

  /// Marks a row that comes from preventive care rather than from a medication entry, so tapping it opening a different form is not a surprise.
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get medicationListPreventionBadge;

  /// Optional input. Without it the AI only ever restates the calculated figure, which is why the advice read as canned (PM report). Given it, the advice can address the gap between what the dog eats now and what the calculation suggests.
  ///
  /// In en, this message translates to:
  /// **'Currently feeding (g/day, optional)'**
  String get foodPortionCurrentAmountLabel;

  /// Makes clear the field is not required.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if you do not know.'**
  String get foodPortionCurrentAmountHelperText;

  /// Confirms a record was written. PM report: after saving, an ad appeared and the form was still there, with nothing to say whether the save had worked.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get commonSavedMessage;

  /// Warning banner above the toilet timeline. The text used to live in the detector as a Japanese literal, so it stayed Japanese in the English app (PM report).
  ///
  /// In en, this message translates to:
  /// **'A record suggests blood in the stool. Please consider seeing a vet.'**
  String get anomalyBloodInStoolMessage;

  /// Warning banner for a diarrhea streak.
  ///
  /// In en, this message translates to:
  /// **'Diarrhea has continued for {days} days or more. Please consider seeing a vet.'**
  String anomalyProlongedDiarrheaMessage(int days);

  /// Hides the warning banner. PM request: it reappeared on every visit with no way to put it away, including after the problem had been dealt with.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get anomalyDismissButton;

  /// Body of a medication reminder notification. These texts used to be Japanese literals inside the schedulers, so an English user received Japanese notifications.
  ///
  /// In en, this message translates to:
  /// **'Time for medication.'**
  String get reminderMedicationBody;

  /// Medication reminder when a dosage was recorded.
  ///
  /// In en, this message translates to:
  /// **'Time for medication ({dosage}).'**
  String reminderMedicationBodyWithDosage(String dosage);

  /// Title of a preventive care reminder.
  ///
  /// In en, this message translates to:
  /// **'{productName} reminder'**
  String reminderPreventionTitle(String productName);

  /// Body for a vaccine reminder.
  ///
  /// In en, this message translates to:
  /// **'The next dose is due within {days} days. Consider booking a vet visit.'**
  String reminderPreventionVaccineBody(int days);

  /// Body for a preventive medication reminder (heartworm, flea/tick).
  ///
  /// In en, this message translates to:
  /// **'The next dose is due soon.'**
  String get reminderPreventionMedicationBody;

  /// Android notification channel name, shown in the system settings for this app.
  ///
  /// In en, this message translates to:
  /// **'Medication and prevention reminders'**
  String get reminderChannelName;

  /// Android notification channel description, shown in the system settings for this app.
  ///
  /// In en, this message translates to:
  /// **'Reminders for medication and for vaccine, heartworm and flea/tick prevention.'**
  String get reminderChannelDescription;

  /// Heading of the exported PDF. The PDF was written entirely in Japanese literals, so an English user exported a Japanese document.
  ///
  /// In en, this message translates to:
  /// **'{petName} health report'**
  String reportPdfTitle(String petName);

  /// Used in the PDF heading when the pet has no name recorded.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get reportPdfDefaultPetName;

  /// Date range covered by the report.
  ///
  /// In en, this message translates to:
  /// **'Period: {start} to {end}'**
  String reportPdfPeriod(String start, String end);

  /// Section heading above the generated summary.
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get reportPdfSummaryHeading;

  /// Shown in place of the summary when the report was exported without one.
  ///
  /// In en, this message translates to:
  /// **'(This report contains no AI summary.)'**
  String get reportPdfNoSummary;

  /// Section heading above the weight table.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get reportPdfWeightHeading;

  /// Section heading above the toilet count table.
  ///
  /// In en, this message translates to:
  /// **'Toilet frequency'**
  String get reportPdfToiletHeading;

  /// Table column header.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportPdfDateColumn;

  /// Table column header.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get reportPdfWeightColumn;

  /// Table column header.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get reportPdfCountColumn;

  /// Removes a stored consultation. PM request: history should be the owner's to clear.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get consultationHistoryDeleteButton;

  /// Confirmation before removing a stored consultation.
  ///
  /// In en, this message translates to:
  /// **'Delete this consultation?'**
  String get consultationHistoryDeleteConfirmation;

  /// Period filter option meaning no date limit.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get healthRecordFilterAllPeriods;

  /// Period filter option: the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get healthRecordFilterLastMonth;

  /// Period filter option.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get healthRecordFilterLastThreeMonths;

  /// Period filter option.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get healthRecordFilterLastYear;

  /// Category filter option meaning every tag.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get healthRecordFilterAllTags;

  /// Distinct from having no records at all: with filters on, an empty list would otherwise read as the records having disappeared.
  ///
  /// In en, this message translates to:
  /// **'No records match these filters.'**
  String get healthRecordFilterNoMatches;

  /// Resets both filters, so a filtered-empty list is never a dead end.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get healthRecordFilterClear;

  /// Weight input label carrying the unit it expects, so the label and the parsing cannot drift apart. Kilograms in Japanese, pounds in English.
  ///
  /// In en, this message translates to:
  /// **'Weight ({unit})'**
  String weightFieldLabelWithUnit(String unit);

  /// The same for the pet profile, where weight is optional.
  ///
  /// In en, this message translates to:
  /// **'Weight ({unit}) - optional'**
  String petProfileFormWeightLabelWithUnit(Object unit);

  /// Adds another reminder time to a medication. PM request: some courses are several doses a day, and a single time could only describe a once-daily medicine.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get medicationAddReminderTimeButton;

  /// Marks a history entry that came from the food-portion calculator rather than a typed question. PM asked for the two to be distinguishable in the list.
  ///
  /// In en, this message translates to:
  /// **'[Food portion] '**
  String get consultationHistoryFoodPortionPrefix;

  /// Title when the programme is a vaccine. One wording for both kinds called a vaccination a dose of medicine (PM report).
  ///
  /// In en, this message translates to:
  /// **'Add vaccination record'**
  String get preventionRecordFormAddTitleVaccine;

  /// As above, when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit vaccination record'**
  String get preventionRecordFormEditTitleVaccine;

  /// Title when the programme is a preventive medication (heartworm, flea/tick).
  ///
  /// In en, this message translates to:
  /// **'Add medication record'**
  String get preventionRecordFormAddTitleMedication;

  /// As above, when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit medication record'**
  String get preventionRecordFormEditTitleMedication;

  /// What the food-portion screen writes into the consultation history. Separate from the English prompt sent to the model: this one is read by the owner, so it is localized and uses their display units.
  ///
  /// In en, this message translates to:
  /// **'Weight {weight} / {profile} / suggested {amount} (needs {energy} kcal a day, food is {density} kcal/100g)'**
  String foodPortionHistorySummary(
    String weight,
    String profile,
    String amount,
    String energy,
    String density,
  );

  /// Appended to foodPortionHistorySummary when the owner entered what they feed now.
  ///
  /// In en, this message translates to:
  /// **' / currently {amount}'**
  String foodPortionHistoryCurrentAmount(String amount);

  /// Says what deletion costs on the row itself, so a mistaken tap is caught here rather than on the next screen.
  ///
  /// In en, this message translates to:
  /// **'Every record and photo is erased'**
  String get deleteAccountMenuSubtitle;

  /// Free-text field on a vaccination record naming which vaccine was given; the medication equivalent is medicationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Vaccine type'**
  String get preventionVaccineTypeLabel;

  /// Shown when a save fails. The form stays open with everything still filled in -- closing it would throw away what the owner typed, and they would have to enter it again from memory.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get saveFailedRetryMessage;
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
