// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

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
  String get forgotPasswordLink => 'パスワードをお忘れですか？';

  @override
  String get referralCodeLabel => '紹介コード（任意）';

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
  String get forgotPasswordDialogTitle => 'パスワードを再設定';

  @override
  String get forgotPasswordDialogHelperText => '登録済みのメールアドレス宛に再設定用のリンクを送信します';

  @override
  String get cancelButton => 'キャンセル';

  @override
  String get sendButton => '送信';

  @override
  String get passwordResetEmailSent => 'パスワード再設定用のメールを送信しました';

  @override
  String passwordResetEmailFailed(String error) {
    return '送信に失敗しました: $error';
  }

  @override
  String get forcedSignOutMessage => '別の端末でログインされたため、サインアウトしました。';

  @override
  String get switchPetMenuTitle => 'ペットを切り替える・追加する';

  @override
  String get upgradePlanMenuTitle => 'プランをアップグレード';

  @override
  String get upgradePlanMenuSubtitle => 'サブスクリプション・AI相談チケットの購入';

  @override
  String get signOutMenuTitle => 'サインアウト';

  @override
  String get languageMenuTitle => '言語';

  @override
  String get languageMenuSubtitleSystem => '端末の設定に従う';

  @override
  String get languagePickerTitle => '言語を選択';
}
