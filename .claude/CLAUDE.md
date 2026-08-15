# プロジェクト概要
愛犬健康管理アプリ。仕様書は docs/dog_health_app_spec.md を参照。
RevenueCat Shipaton 2026（2026年8月1日〜9月30日）向けの新規アプリ。

# 技術スタック
- フロントエンド：Flutter（最新安定版）
- 認証・DB・ストレージ・通知：Firebase（Auth / Firestore / Storage / Cloud Messaging）
- 課金：RevenueCat SDK（サブスク・消耗型チケット）
- バックエンド：サーバーレス関数（Cloudflare Workers、TypeScript）
- AI機能：Claude API（Haiku 4.5、vision入力含む）

# ディレクトリ構成
lib/
  features/
    auth/         # Agent A
    daily_record/ # Agent B（健康記録・体重・トイレ）
    medical/      # Agent C（通院・薬・予防医療・OCR）
    ai/           # Agent D（AI相談・AIレポート）
    billing/      # Agent E（RevenueCat・広告）
  shared/         # 共通コンポーネント・モデル・ユーティリティ
functions/        # サーバーレス関数（バックエンド）

# コーディング規約
- Effective Dartに準拠し、null safetyを徹底する
- 主要なロジックにはユニットテストを作成する
- 各featureは自分のディレクトリ配下のみを変更し、他featureのディレクトリは直接編集しない（共通で使うモデル等は shared/ に置く）
- APIキー・シークレットはコードに直書きせず環境変数化し、.gitignoreで除外する
- コミットメッセージはConventional Commits形式（feat:, fix:, docs: 等）を使用する

# 着手前チェックリスト（コーディングを始める前に必ず確認する）

過去に実際に作り込んだ不具合を再発させないための項目。**新機能・修正のどちらでも、コードを書き始める前に該当有無を確認すること。**

## 表示文言とAIプロンプトの分離
- **AIプロンプトは英語で一元管理する。ただしプロンプト文字列を保存・表示に流用してはならない。**
  ユーザーが後から読むもの（相談履歴・レポート等）は、同じ数値から**表示用に別途組み立てる**。二重管理になるが、これは意図的な判断（PM決定 2026-08-15）。
  - 実例：給餌量相談がプロンプトをそのまま履歴に保存し、`Keep it brief` までユーザーに見えていた。
- 回答の言語は `languageCode` でピン留めする。プロンプト自体を翻訳しない。
- ユーザーに見える文字列は必ず `l10n` 経由。ハードコードした日本語・英語を残さない。
- **新しい l10n キーは `app_ja.arb` と `app_en.arb` の両方に追加する。**

## 単位・日付
- 表示は言語設定に追従させる（`formatWeight` / `formatFoodQuantity` / `formatDate` / `weightInputText` 等を使う）。
- **保存は正規化した単位のまま**（体重は kg、フードは g）。表示単位で保存しない。

## 広告
- **1アクションにつき1回**。保存やAI相談が失敗したときは出さない（ユーザーは何も得ていない）。
- **再試行でも出さない。** 画面単位のフラグで抑止する（`_adAlreadyShown`）。

## 保存失敗時
- 画面を閉じない。入力内容を保持したまま留まり、再登録を促す（`saveFailedRetryMessage`）。

## 実機ビルド
- **`--dart-define-from-file=config/prod.json` を必ず付ける。**
  付け忘れると `AI_BACKEND_BASE_URL` が空になり、ローカル開発ホストへフォールバックしてAI機能が全滅する。ビルドもテストも通るので気づけない。
  ```
  flutter build apk --release --dart-define-from-file=config/prod.json
  ```

# 注意事項
- ワクチン・投薬・体重・トイレ等の医療情報を扱うため、ユーザー本人以外がアクセスできないようアクセス制御を必ず実装する
- AI機能（相談・OCR・レポート）はコスト管理のため、レート制限とエラーハンドリングを必ず組み込む
