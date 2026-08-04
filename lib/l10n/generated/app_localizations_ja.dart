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

  @override
  String get saveButton => '保存';

  @override
  String get requiredFieldValidationError => '必須項目です';

  @override
  String get notSetLabel => '未設定';

  @override
  String get preventionTypeVaccine => 'ワクチン';

  @override
  String get preventionTypeMedication => '投薬';

  @override
  String get scheduleTypeMonthly => '毎月';

  @override
  String get scheduleTypeAnnual => '毎年';

  @override
  String get medicalTabVisits => '通院';

  @override
  String get medicalTabMedications => '薬';

  @override
  String get medicalTabPrevention => '予防医療';

  @override
  String get medicalTabCertificates => '証明書';

  @override
  String get medicationFormAddTitle => '薬の記録を追加';

  @override
  String get medicationFormEditTitle => '薬の記録を編集';

  @override
  String get medicationNameLabel => '薬品名';

  @override
  String get medicationDosageLabel => '用量';

  @override
  String get medicationStartDateLabel => '開始日';

  @override
  String get medicationOngoingSwitchLabel => '継続中（終了日未定）';

  @override
  String get medicationEndDateLabel => '終了日';

  @override
  String get medicationReminderSwitchLabel => 'リマインダーを有効にする';

  @override
  String get medicationReminderTimeLabel => 'リマインダー時刻';

  @override
  String get medicationListTitle => '薬の記録';

  @override
  String get medicationListEmptyMessage => '薬の記録がありません';

  @override
  String get medicationOngoingLabel => '継続中';

  @override
  String medicationEndDateSubtitle(String date) {
    return '〜$date';
  }

  @override
  String get certificateListTitle => '証明書一覧';

  @override
  String get certificateListEmptyTitle => '登録済みの証明書がありません';

  @override
  String get certificateListEmptyDescription =>
      '証明書は「予防医療」タブでワクチン・フィラリア・ノミダニ予防の記録を追加するときに撮影・登録します。';

  @override
  String get certificateAddPreventionRecordLabel => '予防医療の記録を追加する';

  @override
  String get preventionProgramFormAddTitle => '予防プログラムを追加';

  @override
  String get preventionProgramFormEditTitle => '予防プログラムを編集';

  @override
  String get preventionTypeFieldLabel => '種別';

  @override
  String get preventionProductNameLabel => 'ワクチン名／予防薬名';

  @override
  String get scheduleTypeFieldLabel => '頻度';

  @override
  String get scheduleTypeSingleOption => '単発（都度登録）';

  @override
  String get scheduleTypeCustomOption => 'カスタム間隔';

  @override
  String get intervalDaysLabel => '間隔（日数）';

  @override
  String get numericValueValidationError => '数値を入力してください';

  @override
  String get preventionProgramActiveSwitchLabel => '有効';

  @override
  String get preventionProgramListTitle => '予防医療プログラム';

  @override
  String get preventionProgramListEmptyMessage => '予防プログラムがありません';

  @override
  String get scheduleTypeSingleBadge => '単発';

  @override
  String scheduleIntervalDaysLabel(int days) {
    return '$days日ごと';
  }

  @override
  String get preventionProgramInactiveSuffix => '（無効）';

  @override
  String get savingInProgressMessage => '保存中です。しばらくお待ちください';

  @override
  String get preventionRecordFormAddTitle => '投与記録を追加';

  @override
  String get preventionRecordFormEditTitle => '投与記録を編集';

  @override
  String get administeredAtLabel => '実施日';

  @override
  String get hospitalNameOptionalLabel => '動物病院名（自宅投与の場合は任意）';

  @override
  String get nextDueDateLabel => '次回予定日';

  @override
  String get certificateImageSectionTitle => '証明書（画像）';

  @override
  String get certificateAlreadyRegisteredMessage => '登録済みの証明書があります';

  @override
  String get certificateNotRegisteredMessage => '証明書は未登録です';

  @override
  String get certificateCaptureManualLabel => '証明書を撮影／選択（自動読取は準備中）';

  @override
  String get certificateCaptureAiLabel => '証明書を撮影／選択してAIで自動入力';

  @override
  String get ocrReadFailedMessage => '読み取れませんでした。手動で入力してください';

  @override
  String ocrConfidenceLabel(String percent) {
    return 'AI読み取り信頼度: $percent%（内容は必ずご確認ください）';
  }

  @override
  String get vaccinationHistoryLabel => '接種履歴';

  @override
  String get medicationHistoryLabel => '投薬履歴';

  @override
  String get vaccinationRecordLabel => '接種記録';

  @override
  String get medicationRecordLabel => '投薬記録';

  @override
  String preventionRecordListTitle(String productName, String historyLabel) {
    return '$productName の$historyLabel';
  }

  @override
  String preventionRecordListEmptyMessage(String recordLabel) {
    return '$recordLabelがありません';
  }

  @override
  String nextDueDatePrefixLabel(String date) {
    return '次回: $date';
  }

  @override
  String get visitFormAddTitle => '通院記録を追加';

  @override
  String get visitFormEditTitle => '通院記録を編集';

  @override
  String get visitedAtLabel => '通院日';

  @override
  String get hospitalNameLabel => '動物病院名';

  @override
  String get diagnosisLabel => '診断内容';

  @override
  String get visitCostLabel => '費用（円）';

  @override
  String get nextVisitDateLabel => '次回通院予定日';

  @override
  String get visitListTitle => '通院履歴';

  @override
  String get visitListEmptyMessage => '通院記録がありません';

  @override
  String get visitFallbackTitle => '通院記録';

  @override
  String visitCostYenSuffix(int cost) {
    return '$cost円';
  }

  @override
  String get aiDisclaimerText =>
      '本機能は医療診断ではなく、受診目安の参考情報です。症状が続く場合や心配な場合は、必ず動物病院を受診してください。';

  @override
  String get aiEmergencyMessage =>
      '至急動物病院へ連絡・受診してください。\nこの内容は緊急性が高い可能性があるため、AIによる回答はスキップし、すぐに動物病院に相談することをおすすめします。';

  @override
  String get aiUpgradeCardButtonLabel => 'チケットを購入 / 有料プランを見る';

  @override
  String get consultationScreenAppBarTitle => 'AI相談';

  @override
  String get consultationReferenceRecordsLabel => '関連する記録を参照する（任意）';

  @override
  String get consultationInputHintText => '気になる症状や様子を入力してください（例：今朝からぐったりしている）';

  @override
  String get consultationSubmitButton => '相談する';

  @override
  String get consultationUsageLimitMessage =>
      '今月の無料相談回数とチケットを使い切りました。チケットを購入するか、有料プランにアップグレードすると引き続きご利用いただけます。';

  @override
  String get consultationSubmitFailedMessage =>
      '相談の送信に失敗しました。通信状況をご確認のうえ、もう一度お試しください。';

  @override
  String get consultationHistoryTitle => '相談履歴';

  @override
  String get consultationHistoryEmptyMessage => '相談履歴はまだありません。';

  @override
  String get foodPortionAppBarTitle => '餌の量を計算';

  @override
  String get foodPortionWeightLabel => '体重 (kg)';

  @override
  String get foodPortionLifeStageLabel => 'ライフステージ';

  @override
  String foodPortionNeuteredStatusLabel(String status) {
    return '避妊・去勢：$status（プロフィールの登録内容）';
  }

  @override
  String get neuteredStatusDone => '済み';

  @override
  String get neuteredStatusNotDone => '未';

  @override
  String get foodPortionBodyConditionLabel => '体型（ボディコンディション）';

  @override
  String get foodPortionBodyConditionHelperText =>
      'あばら骨に触れやすい＝痩せ気味／触れるが見えない＝標準／触れにくい＝ぽっちゃり気味';

  @override
  String get foodPortionActivityLevelLabel => '活動レベル';

  @override
  String get foodPortionPuppyNoteText => '※ 成長期の子犬は体型・活動量に関わらず、年齢に応じた係数で算出します。';

  @override
  String get foodPortionCalorieDensityLabel => 'フードのカロリー密度 (kcal/100g)';

  @override
  String get foodPortionCalorieDensityHelperText =>
      'フードのパッケージに記載されている値を入力してください';

  @override
  String get foodPortionCalculateButton => '計算する';

  @override
  String get foodPortionRerLabel => '安静時代謝エネルギー (RER)';

  @override
  String get foodPortionMerLabel => '1日の目安摂取カロリー (MER)';

  @override
  String get foodPortionDailyFoodLabel => '1日あたりの給餌量';

  @override
  String foodPortionKcalPerDayValue(int value) {
    return '$value kcal/日';
  }

  @override
  String foodPortionGramsPerDayValue(int value) {
    return '$value g/日';
  }

  @override
  String get foodPortionResultDisclaimerText =>
      '※ 目安です。体調・体型の変化に応じて調整し、詳しくは獣医師にご相談ください。';

  @override
  String get foodPortionRequestAdviceButton => 'AIに給餌のアドバイスを聞く';

  @override
  String get foodPortionAdviceUsageLimitMessage => 'AI相談の利用回数上限に達しています。';

  @override
  String get foodPortionAdviceFailedMessage => 'アドバイスの取得に失敗しました。';

  @override
  String get foodPortionAdviceRetryButton => '再試行';

  @override
  String get dogLifeStagePuppyLabel => '子犬（成長期）';

  @override
  String get dogLifeStageAdultLabel => '成犬';

  @override
  String get bodyConditionUnderweightLabel => '痩せ気味';

  @override
  String get bodyConditionIdealLabel => '標準';

  @override
  String get bodyConditionOverweightLabel => 'ぽっちゃり気味';

  @override
  String get activityLevelLowLabel => '運動量少なめ';

  @override
  String get activityLevelNormalLabel => '普通';

  @override
  String get activityLevelHighLabel => '活発';

  @override
  String get reportAppBarTitle => 'AI健康レポート';

  @override
  String get reportExportPdfTooltip => 'PDFで書き出す';

  @override
  String reportPeriodLabel(String start, String end) {
    return '対象期間: $start 〜 $end';
  }

  @override
  String get reportWeightTrendTitle => '体重の推移';

  @override
  String get reportToiletTrendTitle => 'トイレ回数の推移';

  @override
  String get reportAiSummaryTitle => 'AIサマリー';

  @override
  String get reportGenerationFailedMessage => 'レポート生成に失敗しました。もう一度お試しください。';

  @override
  String get reportGenerateSummaryButton => 'AIサマリーを生成';

  @override
  String get reportSummaryUsageLimitMessage =>
      'AIサマリーは有料プラン限定機能です。グラフは無料版でも引き続きご覧いただけます。';

  @override
  String get reportNoWeightDataMessage => '体重の記録がありません。';

  @override
  String get reportNoToiletDataMessage => 'トイレの記録がありません。';

  @override
  String get reportUrineLegendLabel => '排尿';

  @override
  String get reportStoolLegendLabel => '排便';
}
