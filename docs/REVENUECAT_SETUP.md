# RevenueCat 設定手順（wanote）

作成: 2026-08-18
対象: **システムに詳しくない方が、上から順にそのまま進められる**ことを目指した手順です。

---

# ⚠️ 最初に読んでください

## 所要時間と順番

- Apple 側 … 30〜40分
- Google 側 … 30〜40分（**反映に最大36時間かかります**）
- RevenueCat 側 … 30分

**Google の反映待ちが最大36時間あります。** 今日中に課金テストまでは終わりません。
**先に Google（第2部）から始めてください。** 待ち時間を Apple の作業に使えます。

## 絶対に間違えてはいけないもの

アプリは**下の文字列をそのまま探しに行きます。** 1文字でも違うと、
「購入ボタンが出ない」「購入しても機能が解放されない」という形で失敗します。
**コピー＆ペーストしてください。手入力しないでください。**

| 何の値か | 入力する文字列 |
|---|---|
| 商品ID（月額サブスク） | `premium_monthly` |
| 商品ID（年額サブスク） | `premium_yearly` |
| 商品ID（AIチケット5回） | `ai_tickets_5` |
| 商品ID（AIチケット15回） | `ai_tickets_15` |
| Entitlement（権利）の識別子 | `premium` |

## 用語（3つだけ覚えれば大丈夫です）

| 用語 | 意味 | wanote での例 |
|---|---|---|
| **Product（商品）** | ストアで売る品物そのもの | 月額プラン、チケット5回 |
| **Entitlement（権利）** | 「買うと何ができるか」のラベル | `premium`（広告なし＋AI無制限） |
| **Offering（売り場）** | アプリに表示する商品の並び | プラン画面に出る4つ |

月額を買っても年額を買っても「プレミアムが使える」のは同じです。
その「同じ」をまとめるのが Entitlement です。アプリは商品名ではなく
**`premium` を持っているかどうか**だけを見ています。

---

# 第2部を先に：Google（Play Console ＋ Google Cloud）

## 前提

Google Play で課金を設定するには、**アプリが1度は内部テストにアップロードされている**
必要があります。まだの場合は先に AAB を内部テストへ上げてください。

## G-1. 定期購入を2つ作る

https://play.google.com/console

1. **wanote** を開く
2. 左メニュー **収益化** → **定期購入**
3. **定期購入を作成**
   - **プロダクトID: `premium_monthly`**
   - ⚠️ **一度保存すると変更できません。** 貼り付けた文字を確認してください
   - 名前: `プレミアム（月額）`
4. 作成後、**基本プラン**を追加
   - 基本プランID: `monthly`
   - 請求期間: **毎月**
   - 価格を設定 → **有効化**
   - ※ 基本プランを有効化しないと購入できる状態になりません
5. 同様に2つ目
   - **プロダクトID: `premium_yearly`** / 基本プランID `yearly` / 請求期間 **毎年**

## G-2. アプリ内アイテム（チケット）を2つ作る

1. 左メニュー **収益化** → **アプリ内アイテム**
2. **アイテムを作成**
   - **プロダクトID: `ai_tickets_5`**
   - 名前・説明・価格 → **有効化**
3. 同様に **`ai_tickets_15`**

## G-3. サービスアカウントを作る

RevenueCat が Google に購入内容を問い合わせるための「専用の入館証」です。

### (A) API を2つ有効化

1. https://console.cloud.google.com を開く
2. 画面上部で、Play Console と紐づくプロジェクトを選択
3. 上部の検索窓に `Google Play Android Developer API` → **有効にする**
4. 同様に `Google Play Developer Reporting API` → **有効にする**

### (B) サービスアカウントと鍵を作る

1. 左メニュー **IAMと管理** → **サービス アカウント**
2. **サービス アカウントを作成**
   - 名前: `revenuecat`
   - ロールは**付けなくて構いません**（権限は次の Play Console 側で付けます）
3. 作成された行の右端「⋮」→ **鍵を管理**
4. **鍵を追加** → **新しい鍵を作成** → **JSON** → 作成
   - JSON がダウンロードされます
   - 🔒 **これは秘密の鍵です。** リポジトリの外（例 `C:\Dev\keys\`）に保存してください
5. サービスアカウントの**メールアドレス**を控える
   （`revenuecat@＜プロジェクト名＞.iam.gserviceaccount.com` の形）

### (C) Play Console 側で権限を与える

1. Play Console → 左下 **ユーザーと権限**
2. **新しいユーザーを招待**
3. メールアドレス欄に (B)-5 のアドレスを貼る
4. **アプリの権限** で **wanote** を選択
5. 権限は以下にチェック
   - 財務データ、注文、定期購入の閲覧
   - 注文と定期購入の管理
6. **ユーザーを招待**

> ⏳ **ここから最大36時間、反映を待ちます。**
> その間 RevenueCat 側で「Invalid Play Store credentials」と出ますが**故障ではありません**。

---

# 第1部　Apple（App Store Connect）

https://appstoreconnect.apple.com

## A-1. サブスクリプションを2つ作る

1. **マイApp** → **wanote**
2. 左メニュー **収益化** → **サブスクリプション**
3. **サブスクリプショングループ** の「＋」
   - グループ参照名: `Premium`（内部用。ユーザーには見えません）
   - ※ Apple はサブスクを必ずグループに入れる決まりです。
     同じグループ内なら月額↔年額の乗り換えが自動処理されます
4. グループを開き、**サブスクリプション**の「＋」
   - 参照名: `プレミアム月額`
   - **製品ID: `premium_monthly`**
5. 作成後、その商品の画面で
   - **期間**: 1か月
   - **価格**: 日本を選び設定
   - **App Store 情報**（表示名・説明）: **日本語と英語の両方**
     - 表示名の例「wanote プレミアム（月額）」
     - 説明の例「広告非表示、AI相談が使い放題、AI健康レポートが利用できます。」
6. 同じグループに2つ目
   - 参照名: `プレミアム年額` / **製品ID: `premium_yearly`** / 期間 1年

> 年額は月額×12より安くするのが通例です（例: 月額500円 → 年額5,000円）。
> 価格は事業判断なのでPMのご判断で。

## A-2. チケット（消耗型）を2つ作る

1. 左メニュー **収益化** → **App内課金**
2. 「＋」→ **消耗型** を選択
   - ⚠️ **必ず「消耗型」**。「非消耗型」にすると1回しか買えなくなります
   - 参照名: `AIチケット5回` / **製品ID: `ai_tickets_5`**
   - 価格・表示名・説明（日英）
3. 同様に `AIチケット15回` / **製品ID: `ai_tickets_15`**

## A-3. In-App Purchase キーを作る

RevenueCat が Apple に購入内容を問い合わせるための鍵です。

1. 右上のアカウント名 → **ユーザーとアクセス**
2. 上部タブ **統合** → 左メニュー **App内課金**
3. **「＋」** → 名前: `RevenueCat`
4. **ダウンロード** → `.p8` ファイルが落ちてきます
   - ⚠️ **1度しかダウンロードできません。** リポジトリの外に保存してください
5. 同じ画面の次の2つも控える
   - **キーID**（10文字程度）
   - **Issuer ID**（画面上部の長いUUID）

## A-4. 控えるもの

- [ ] `.p8` ファイル / キーID / Issuer ID
- [ ] Bundle ID: `jp.wanote.app`

---

# 第3部　RevenueCat

https://app.revenuecat.com

## R-1. プロジェクトとアプリ

1. **Create new project** → 名前 `wanote`
2. プロジェクト設定 → **Apps** → **＋ New**
3. **App Store** を選択
   - App name: `wanote (iOS)`
   - **Bundle ID: `jp.wanote.app`**
   - **In-App Purchase Key**: A-3 の `.p8` をアップロードし、
     **Issuer ID** と **Key ID** を貼り付け
4. 再度 **＋ New** → **Play Store**
   - App name: `wanote (Android)`
   - **Package name: `jp.wanote.app`**
   - **Service Account credentials JSON**: G-3 の JSON をアップロード

## R-2. 商品を取り込む

1. 左メニュー **Product catalog** → **Products**
2. **＋ New** → iOS アプリを選び、4つの商品IDを登録
3. Android アプリでも同じ4つを登録
   - 定期購入は `premium_monthly:monthly` のように
     「プロダクトID:基本プランID」で表示されることがあります。それを選んでください

**合計8件（iOS 4件＋Android 4件）**になります。

## R-3. Entitlement を作る（ここが一番重要です）

1. **Product catalog** → **Entitlements** → **＋ New**
2. **Identifier: `premium`** / 説明: `広告非表示・AI無制限・レポート`
3. **Attach** で、次の**4件だけ**を紐付ける
   - iOS `premium_monthly`
   - iOS `premium_yearly`
   - Android `premium_monthly`
   - Android `premium_yearly`

> ❌ **チケット2種は絶対に紐付けないでください。**
> 紐付けると、チケットを1枚買っただけで**永久にプレミアム**になります。
> チケットの枚数はアプリ側が別にカウントしています。

## R-4. Offering（売り場）を作る

1. **Product catalog** → **Offerings** → **＋ New**
2. Identifier: `default` / Description: `プラン画面`
3. ★ **作成後、この Offering を「Current」（既定）にしてください**
   - アプリは **Current の Offering だけ**を読みます。ここを忘れると
     プラン画面が「現在ご利用いただけるプランがありません」になります
4. **Packages** を4つ追加し、各パッケージに iOS と Android の商品を1つずつ紐付ける

   | Package | 紐付ける商品 |
   |---|---|
   | `$rc_monthly` | `premium_monthly`（iOS / Android） |
   | `$rc_annual` | `premium_yearly`（iOS / Android） |
   | `tickets_5` | `ai_tickets_5`（iOS / Android） |
   | `tickets_15` | `ai_tickets_15`（iOS / Android） |

   > `$rc_monthly` などは RevenueCat の定型IDです。チケットには定型IDが無いので
   > 任意の名前で構いません。**パッケージ名はアプリの判定に使っていません。**

## R-5. 公開APIキーを控える

1. プロジェクト設定 → **API keys**
2. **Public app-specific API keys** の2つを控える
   - iOS 用（`appl_` で始まる）
   - Android 用（`goog_` で始まる）

> このキーは**アプリに埋め込まれる公開キー**で、秘密情報ではありません
> （アプリのバイナリから読み出せる前提の値です）。

## R-6. シークレットキー（サーバー用）

キャンペーンコードでプレミアムを付与する機能がサーバー側にあり、**秘密鍵**を使います。

1. 同じ **API keys** の画面で **Secret API key** を作成（`sk_` で始まる）
2. 🔒 **この鍵は私には渡さないでください。** 下のコマンドをPMご自身で実行してください

```bash
cd C:/Dev/wanote/functions && npx wrangler secret put REVENUECAT_SECRET_KEY
```

実行すると値の入力を求められるので、そこに貼り付けます。

---

# 第4部　アプリ側への反映

R-5 の**公開キー2つ**を `C:\Dev\wanote\config\prod.json` に追記します。
現在は1行だけです。次のように書き換えてください（`xxx` を実際の値に）。

```json
{
  "AI_BACKEND_BASE_URL": "https://wanote-functions.wanote-app-reply.workers.dev",
  "REVENUECAT_API_KEY_IOS": "appl_xxxxxxxxxxxxxxxx",
  "REVENUECAT_API_KEY_ANDROID": "goog_xxxxxxxxxxxxxxxx"
}
```

> 商品IDと Entitlement は、**この手順書どおりの名前なら追記不要**です
> （アプリ側の既定値と一致しています）。

このファイルは Git に入りません（`.gitignore` 済み）。
編集後にお知らせいただければ、ビルドして端末に入れます。

**Codemagic（iOS）にも同じ2つが必要です。** 環境変数
`REVENUECAT_API_KEY_IOS` / `REVENUECAT_API_KEY_ANDROID` を
`wanote_ios` グループに追加してください（Secure にチェック）。
※ ビルド側で受け取る処理は、キーが用意でき次第こちらで対応します。

---

# 第5部　動作確認

## 最初の判定点

設定が効くと、**設定 → プランをアップグレード** が
「準備中です」から**商品4つの一覧**に変わります。

## テスト購入の準備

- **iOS**: App Store Connect → **ユーザーとアクセス** → **Sandbox** でテスターを追加。
  実機の「設定 → App Store → サンドボックスアカウント」でサインイン
- **Android**: Play Console → **設定 → ライセンステスト** にアカウントを追加。
  内部テストのトラックに参加していることが必要

**どちらも実際の課金は発生しません。**

## うまくいかないときの見分け方

| 症状 | 原因 |
|---|---|
| 「準備中です」のまま | 公開APIキーが未設定、またはビルドに含まれていない |
| 「ご利用いただけるプランがありません」 | Offering が **Current** になっていない |
| 一部の商品だけ出ない | ストア側でその商品が「有効化」されていない／審査待ち |
| 商品名がストアの名前で出る | 商品IDが表と違う（アプリが名前を判別できていない） |
| 購入できたのに広告が消えない | Entitlement `premium` に商品が紐付いていない |
| Android で Invalid Play Store credentials | 36時間の反映待ち。時間をおいて再確認 |

---

# 付録　チェックリスト

- [ ] Google: 定期購入2つ（基本プラン**有効化**まで）
- [ ] Google: アプリ内アイテム2つ（**有効化**まで）
- [ ] Google: サービスアカウント JSON ＋ Play Console で権限付与
- [ ] Apple: `premium_monthly` `premium_yearly`（同一グループ）
- [ ] Apple: `ai_tickets_5` `ai_tickets_15`（**消耗型**）
- [ ] Apple: In-App Purchase キー（.p8 / キーID / Issuer ID）
- [ ] RevenueCat: iOS / Android の2アプリ登録・認証情報アップロード
- [ ] RevenueCat: 商品8件の取り込み
- [ ] RevenueCat: Entitlement `premium` に**サブスク4件だけ**紐付け
- [ ] RevenueCat: Offering を作成し **Current に設定**
- [ ] `config/prod.json` に公開キー2つ
- [ ] Worker に `REVENUECAT_SECRET_KEY`（PMが実行）
- [ ] Codemagic に公開キー2つ

---

# 出典

- RevenueCat Quickstart — https://www.revenuecat.com/docs/getting-started/quickstart
- Entitlements — https://www.revenuecat.com/docs/getting-started/entitlements
- Products / Offerings — https://www.revenuecat.com/docs/offerings/products-overview
- Google Play service credentials — https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials
- App-Specific Shared Secret（現在は In-App Purchase Key が推奨） —
  https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret
