# -*- coding: utf-8 -*-
"""Apply the corrected Japanese translations to lib/l10n/app_ja.arb,
line-by-line (preserves exact file formatting/ordering) rather than a
full JSON rewrite.
"""
import re

PATH = r"C:\Dev\wanote\lib\l10n\app_ja.arb"

TRANSLATIONS = {
    "createAccountTitle": "アカウントを作成",
    "emailValidationError": "有効なメールアドレスを入力してください",
    "passwordValidationError": "パスワードは6文字以上で入力してください",
    "signInButton": "サインイン",
    "signInTitle": "サインイン",
    "signInWithApple": "Appleでサインイン",
    "signInWithGoogle": "Googleでサインイン",
    "signUpButton": "サインアップ",
    "switchToSignInLink": "すでにアカウントをお持ちですか？サインイン",
    "switchToSignUpLink": "初めてご利用ですか？アカウントを作成",
    "biometricGateAppBarTitle": "wanoteのロックを解除",
    "biometricGateContinueButton": "続ける",
    "biometricGateIncorrectPasswordError": "パスワードが正しくありません。もう一度お試しください。",
    "biometricGateMismatchMessage": "生体認証が一致しませんでした。",
    "biometricGatePasswordPrompt": "続行するにはパスワードを入力してください。",
    "biometricGateReauthFailedError": "サインインを完了できませんでした。",
    "biometricGateReauthPrompt": "続行するにはもう一度サインインしてください。",
    "biometricGateRetryButton": "もう一度試す",
    "biometricGateUnlockButton": "ロック解除",
    "biometricSetupAppBarTitle": "生体認証ログイン",
    "biometricSetupDescription": "次回からパスワードを入力する代わりに、Face ID／Touch ID／指紋認証でwanoteのロックを解除できます。生体認証データ自体がこの端末の外に送信されることはありません。",
    "biometricSetupEnableButton": "有効にする",
    "biometricSetupHeadline": "生体認証ログインを有効にしますか？",
    "biometricSetupSkipButton": "今はしない",
    "addPetButton": "ペットを追加",
    "petProfileFormBirthdayLabel": "誕生日：{date}",
    "petProfileFormBirthdayRequiredMessage": "誕生日を選択してください",
    "petProfileFormBreedLabel": "犬種",
    "petProfileFormNameLabel": "名前",
    "petProfileFormNameRequiredError": "名前を入力してください",
    "petProfileFormNeuteredLabel": "去勢・避妊済み",
    "petProfileFormSelectBirthdayLabel": "誕生日を選択",
    "petProfileFormSexLabel": "性別",
    "petProfileFormWeightLabel": "体重（kg）- 任意",
    "petProfileFormWeightValidationError": "有効な数値を入力してください",
    "petSexOptionFemale": "メス",
    "petSexOptionMale": "オス",
    "noPetsYetMessage": "まだペットが登録されていません。下から最初のペットを追加してください。",
    "removePetDialogCancelButton": "キャンセル",
    "removePetDialogConfirmButton": "削除",
    "removePetDialogContent": "{petName}をこのアカウントから削除しますか？",
    "removePetDialogTitle": "ペットを削除",
    "aiTickets15Label": "AI相談チケット x15",
    "aiTickets5Label": "AI相談チケット x5",
    "paywallAppBarTitle": "プレミアム & AIチケット",
    "premiumMonthlyLabel": "プレミアム（月額）",
    "premiumYearlyLabel": "プレミアム（年額）",
    "weightDuplicateDateDialogContent": "上書きしますか？それとも追加の記録として保存しますか？",
}

with open(PATH, encoding="utf-8") as f:
    lines = f.readlines()

seen = set()
out = []
for line in lines:
    m = re.match(r'^(\s*")([A-Za-z0-9_]+)("\s*:\s*")(.*)("\s*,?\s*\n?)$', line)
    if m and m.group(2) in TRANSLATIONS:
        key = m.group(2)
        new_val = TRANSLATIONS[key]
        out.append(f'{m.group(1)}{key}{m.group(3)}{new_val}{m.group(5)}')
        seen.add(key)
    else:
        out.append(line)

missing = set(TRANSLATIONS) - seen
if missing:
    raise SystemExit(f"Keys not found in {PATH}: {sorted(missing)}")

with open(PATH, "w", encoding="utf-8", newline="") as f:
    f.writelines(out)

print(f"Updated {len(seen)} keys in {PATH}")
