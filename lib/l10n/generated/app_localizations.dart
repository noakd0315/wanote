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
