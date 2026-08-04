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
  String get campaignCodeSectionTitle => 'プロモーションコードをお持ちですか？';

  @override
  String get campaignCodeSignInRequired => 'サインインしてからお試しください。';

  @override
  String get campaignCodeRedeemedMessage => 'プレミアムを1ヶ月分付与しました。ありがとうございます！';

  @override
  String get campaignCodeUnknownError => 'このコードは見つかりませんでした。';

  @override
  String get campaignCodeInactiveError => 'このコードは現在無効です。';

  @override
  String get campaignCodeCapReachedError => 'このコードは利用上限に達しています。';

  @override
  String get campaignCodeAlreadyRedeemedError => 'このコードは既に使用済みです。';

  @override
  String get campaignCodeSelfReferralError => '自分の紹介コードは使用できません。';

  @override
  String get campaignCodeHintText => 'コードを入力';

  @override
  String get campaignCodeApplyButton => '適用する';

  @override
  String referralCodeDisplay(String code) {
    return 'あなたの紹介コード: $code';
  }

  @override
  String get copyTooltip => 'コピー';

  @override
  String get referralCodeCopiedMessage => '紹介コードをコピーしました。';

  @override
  String get aiSectionConsultationTab => '相談';

  @override
  String get aiSectionReportTab => 'レポート';

  @override
  String get dailyRecordHealthTab => '健康記録';

  @override
  String get dailyRecordWeightTab => '体重';

  @override
  String get dailyRecordToiletTab => 'トイレ';

  @override
  String get homeShortcutWeightLabel => '体重';

  @override
  String get homeShortcutToiletLabel => 'トイレ';

  @override
  String get homeShortcutCertificatesLabel => '証明書';

  @override
  String get homeShortcutConsultationLabel => 'AI相談';

  @override
  String get homeShortcutFoodPortionLabel => '餌の量';

  @override
  String get navHomeLabel => 'ホーム';

  @override
  String get navDailyRecordLabel => '日常記録';

  @override
  String get navMedicalLabel => '医療';

  @override
  String get navAiConsultationLabel => 'AI相談';

  @override
  String get navSettingsLabel => '設定・課金';

  @override
  String get referralCodeAppliedMessage => '紹介コードを適用し、プレミアムを1ヶ月分付与しました。';

  @override
  String get imageSourceCameraOption => 'カメラで撮影';

  @override
  String get imageSourceGalleryOption => 'フォトライブラリから選択';

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
  String get petProfileFormSavingInProgressMessage => '保存中です。しばらくお待ちください';

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
  String get petProfileFormIconSectionTitle => 'アイコン写真';

  @override
  String get petProfileFormDeleteIconButton => 'アイコン写真を削除';

  @override
  String get petProfileFormIconOffsetXLabel => '左右';

  @override
  String get petProfileFormIconOffsetYLabel => '上下';

  @override
  String get petProfileFormIconZoomLabel => 'ズーム';

  @override
  String get petProfileFormBackgroundSectionTitle => '背景写真（ホーム画面）';

  @override
  String get petProfileFormChangeBackgroundButton => '変更';

  @override
  String get petProfileFormDeleteBackgroundButton => '削除';

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
