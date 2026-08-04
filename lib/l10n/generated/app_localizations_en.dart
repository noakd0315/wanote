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
}
