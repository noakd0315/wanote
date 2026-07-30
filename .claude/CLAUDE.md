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

# 注意事項
- ワクチン・投薬・体重・トイレ等の医療情報を扱うため、ユーザー本人以外がアクセスできないようアクセス制御を必ず実装する
- AI機能（相談・OCR・レポート）はコスト管理のため、レート制限とエラーハンドリングを必ず組み込む
