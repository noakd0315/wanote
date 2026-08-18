# RevenueCat 設定手順（wanote）

作成: 2026-08-18 / **AABの先行アップロードが必要と判明したため全面改訂**
対象: **システムに詳しくない方が、上から順にそのまま進められる**ことを目指した手順です。

---

# この手順の全体像

```
第0部  アップロード鍵を作る → AABを作る → 内部テストへ上げる    ← ここが起点
   ↓   （※Play Consoleは、ビルドを上げるまで商品を作らせません）
第1部  Google: 商品4つ ＋ サービスアカウント                  ← 36時間タイマー開始
   ↓
第2部  Apple: 商品4つ ＋ In-App Purchaseキー                  （待ち時間に実施）
   ↓
第3部  RevenueCat: アプリ2つ・商品・Entitlement・Offering      （待ち時間に実施）
   ↓
第4部  公開キーをアプリに入れて再ビルド → 内部テストへ再アップロード
   ↓
第5部  テスト購入（★Googleの36時間が明けてから）
```

## 今日の到達目標（最低ライン）

**第4部まで**を終わらせれば、今日の作業としては十分です。
第5部のテスト購入は Google 側の反映待ちがあるため、**今日は完了できません**。

第4部まで終わっていれば、翌日は**購入を試すだけ**になります。

## 所要時間

| 部 | 時間 | 誰が |
|---|---|---|
| 第0部 | 20分＋ビルド10分 | 鍵作成＝PM / ビルド＝私 / アップロード＝PM |
| 第1部 | 30〜40分 | PM |
| 第2部 | 30〜40分 | PM |
| 第3部 | 30分 | PM |
| 第4部 | 5分＋ビルド10分 | 貼り付け＝PM / ビルド＝私 |
| 第5部 | 翌日 | PM |

---

# ⚠️ 絶対に間違えてはいけないもの

アプリは**下の文字列をそのまま探しに行きます。** 1文字でも違うと、
「購入ボタンが出ない」「購入しても機能が解放されない」という形で失敗します。
**エラーはどこにも出ません。** コピー＆ペーストしてください。

| 何の値か | 入力する文字列 |
|---|---|
| 商品ID（月額サブスク） | `premium_monthly` |
| 商品ID（年額サブスク） | `premium_yearly` |
| 商品ID（AIチケット5回） | `ai_tickets_5` |
| 商品ID（AIチケット15回） | `ai_tickets_15` |
| Entitlement（権利）の識別子 | `premium` |

## 用語（3つだけ）

| 用語 | 意味 | wanote での例 |
|---|---|---|
| **Product（商品）** | ストアで売る品物そのもの | 月額プラン、チケット5回 |
| **Entitlement（権利）** | 「買うと何ができるか」のラベル | `premium`（広告なし＋AI無制限） |
| **Offering（売り場）** | アプリに表示する商品の並び | プラン画面に出る4つ |

月額を買っても年額を買っても「プレミアムが使える」のは同じです。
その「同じ」をまとめるのが Entitlement です。アプリは商品名ではなく
**`premium` を持っているかどうか**だけを見ています。

---

# 第0部　AABを内部テストへ上げる

## なぜ最初にこれが必要か

**Play Console は、Play Billing ライブラリを含むビルドがトラックに
アップロードされるまで、商品を作らせません。** パッケージ名を実際の
アップロードで確認するまで、商品作成の画面が使えない仕組みです。

**このAABに RevenueCat の設定は一切含まれません。**
商品は Play Console 側に作るものなので、いま手元にあるビルドで構いません。
（現ビルドに `com.android.vending.BILLING` が含まれていることは確認済みです）

## 0-1. アップロード鍵を作る（PM作業）

PowerShell で以下を**そのまま**実行します。

```powershell
keytool -genkey -v -keystore C:\Users\tomoc\wanote-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload -dname "CN=wanote, O=wanote, C=JP"
```

聞かれるのは**パスワードだけ**です。

| # | 画面に出る文言 | 入れるもの |
|---|---|---|
| 1 | キーストアのパスワードを入力してください | 任意のパスワード。**必ず記録** |
| 2 | 新規パスワードを再入力してください | **1と同じものをもう一度** |

最後に次が出たら、**そのままEnter**で完了です。

```
<upload>の鍵パスワードを入力してください
        (キーストアのパスワードと同じ場合はRETURNを押してください):
```

> **なぜ `-dname` を付けるのか**
>
> これを付けないと、姓名・組織・国コードを1つずつ聞かれ、最後に
> 「…でよろしいですか」と確認されます。**この確認が日本語環境では通りません。**
>
> keytool は入力を「表示言語に合わせた肯定語」と比較します。日本語環境では
> `はい` だけが一致し、`yes` も `y` も「いいえ」扱いです。ところが
> PowerShell から日本語を打つと、コンソールの文字コードと Java が読む
> 文字コードが食い違い、**`はい` と打っても一致しません**。
> 結果、何を入れても最初の質問に戻り続けます（PM報告, 2026-08-18）。
>
> `-dname` は、その質問と確認をまとめて省略します。聞かれるのは
> パスワードだけになり、パスワードは半角なので化けません。
>
> `CN=wanote, O=wanote, C=JP` の中身は証明書に記録されるだけで、
> **利用者には表示されません**。Google Play は最終的に Google 自身の鍵で
> 署名し直すため、ストア上の表示にも影響しません。

> **すでに何度か失敗して終了している場合、鍵はまだ作られていません。**
> 上のコマンドで作り直してください。途中まで作られたファイルが残っていたら、
> `del C:\Users\tomoc\wanote-upload.jks` で消してから実行します。

## 0-1b. できたか確認する

```powershell
keytool -list -v -keystore C:\Users\tomoc\wanote-upload.jks -alias upload
```

パスワードを入れて、`別名: upload` と有効期限が表示されれば成功です。

> 🔴 **この .jks とパスワードを失うと、二度とアプリを更新できません。**
> クラウドストレージなど、PCが壊れても残る場所にバックアップしてください。
> Google Play アプリ署名を使うので復旧手段はありますが、手続きは面倒です。

## 0-2. パスワードをアプリのビルド設定に渡す（PM作業）

`C:\Dev\wanote\android\key.properties` を**新規作成**し、以下を書きます。

```properties
storeFile=C:\\Users\\tomoc\\wanote-upload.jks
storePassword=（0-1で決めたパスワード）
keyAlias=upload
keyPassword=（0-1で決めたパスワード。同じで構いません）
```

> - **バックスラッシュは2つ重ねます**（`\\`）。1つだとパスとして読めません
> - このファイルは Git に入りません（`.gitignore` 済み）
> - 🔒 **パスワードは私に送らないでください。** このファイルに書くだけで、
>   ビルドは通ります

## 0-3. AAB を作る（私の作業）

`key.properties` を作り終えたら教えてください。こちらで実行します。

```bash
flutter build appbundle --release --dart-define-from-file=config/prod.json
```

できあがる場所: `build\app\outputs\bundle\release\app-release.aab`

## 0-4. 内部テストへアップロード（PM作業）

1. https://play.google.com/console → **wanote**
2. 左メニュー **テスト** → **内部テスト**
3. **新しいリリースを作成**
4. `app-release.aab` をドラッグ＆ドロップ
5. リリース名・リリースノート（内部用なので簡単で構いません）
6. **保存** → **リリースのレビュー** → **内部テストへの公開を開始**

> 初回は「アプリの設定」に未完了項目があると公開できないことがあります
> （プライバシーポリシーURL、対象年齢、データセーフティ等）。
> 画面の指示に従って埋めてください。ここは審査ではないので即時反映されます。

## 0-5. テスターを登録（PM作業）

1. **内部テスト** の **テスター** タブ
2. **メーリングリストを作成** → ご自身のGoogleアカウントを追加
3. **リンクをコピー**して、そのアカウントの端末で開き、テスターになる

---

# 第1部　Google（Play Console ＋ Google Cloud）

**★ この部を終えた瞬間から、最大36時間の反映待ちが始まります。**
先に済ませるほど、翌日のテストが早く始められます。

## G-1. 定期購入を2つ作る

1. 左メニュー **収益化** → **定期購入**
2. **定期購入を作成**
   - **プロダクトID: `premium_monthly`**
   - ⚠️ **一度保存すると変更できません。** 貼り付けた文字を目視確認してください
   - 名前: `プレミアム（月額）`
3. 作成後、**基本プラン**を追加
   - 基本プランID: `monthly`
   - 請求期間: **毎月**
   - 価格を設定 → **有効化**
   - ※ 基本プランを有効化しないと購入できる状態になりません
4. 同様に2つ目
   - **プロダクトID: `premium_yearly`** / 基本プランID `yearly` / 請求期間 **毎年**

> 年額は月額×12より安くするのが通例です（例: 月額500円 → 年額5,000円）。
> 価格は事業判断なのでPMのご判断で。

## G-2. アプリ内アイテム（チケット）を2つ作る

1. 左メニュー **収益化** → **アプリ内アイテム**
2. **アイテムを作成**
   - **プロダクトID: `ai_tickets_5`**
   - 名前・説明・価格 → **有効化**
3. 同様に **`ai_tickets_15`**

## G-3. サービスアカウントを作る

RevenueCat が Google に購入内容を問い合わせるための「専用の入館証」です。

### (A) API を2つ有効化

1. https://console.cloud.google.com
2. 画面上部で、Play Console と紐づくプロジェクトを選択
3. 上部の検索窓に `Google Play Android Developer API` → **有効にする**
4. 同様に `Google Play Developer Reporting API` → **有効にする**

### (B) サービスアカウントと鍵

1. 左メニュー **IAMと管理** → **サービス アカウント**
2. **サービス アカウントを作成**
   - 名前: `revenuecat`
   - ロールは**付けなくて構いません**（権限は次の Play Console 側で付けます）
3. 作成された行の右端「⋮」→ **鍵を管理**
4. **鍵を追加** → **新しい鍵を作成** → **JSON** → 作成
   - 🔒 **秘密の鍵です。** リポジトリの外（例 `C:\Users\tomoc\keys\`）に保存
5. サービスアカウントの**メールアドレス**を控える
   （`revenuecat@＜プロジェクト名＞.iam.gserviceaccount.com`）

### (C) Play Console 側で権限を与える

1. Play Console → 左下 **ユーザーと権限**
2. **新しいユーザーを招待**
3. メールアドレス欄に (B)-5 のアドレスを貼る
4. **アプリの権限** で **wanote** を選択
5. 権限にチェック
   - 財務データ、注文、定期購入の閲覧
   - 注文と定期購入の管理
6. **ユーザーを招待**

> ⏳ **ここから最大36時間。** RevenueCat 側で
> 「Invalid Play Store credentials」と出ますが**故障ではありません**。

## G-4. ライセンステストを登録（テスト購入で課金されないように）

1. Play Console の**左下 歯車（すべてのアプリ共通の設定）** → **ライセンステスト**
2. ご自身のGoogleアカウントを追加 → **ライセンス応答: RESPOND_NORMALLY**
3. 保存

> ⚠️ **ここに登録していないアカウントで購入すると、実際に課金されます。**
> 内部テスト版でも同じです。必ず登録してください。

---

# 第2部　Apple（App Store Connect）

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

## A-2. チケット（消耗型）を2つ作る

1. 左メニュー **収益化** → **App内課金**
2. 「＋」→ **消耗型** を選択
   - ⚠️ **必ず「消耗型」**。「非消耗型」にすると1回しか買えなくなります
   - 参照名: `AIチケット5回` / **製品ID: `ai_tickets_5`**
3. 同様に `AIチケット15回` / **製品ID: `ai_tickets_15`**

## A-3. In-App Purchase キーを作る

1. 右上のアカウント名 → **ユーザーとアクセス**
2. 上部タブ **統合** → 左メニュー **App内課金**
3. **「＋」** → 名前: `RevenueCat`
4. **ダウンロード** → `.p8` ファイル
   - ⚠️ **1度しかダウンロードできません。** リポジトリの外に保存
5. 同じ画面の **キーID** と、上部の **Issuer ID** も控える

## A-4. Sandbox テスターを登録

1. **ユーザーとアクセス** → **Sandbox** → **テスター**
2. テスト用のメールアドレスで追加（実在しないアドレスでも作れます）
3. iPhone の **設定 → App Store → サンドボックスアカウント** でサインイン

> Apple 側は**アップロード不要**で商品を作れます（Google と違う点です）。

---

# 第3部　RevenueCat

https://app.revenuecat.com

## R-1. プロジェクトとアプリ

1. **Create new project** → 名前 `wanote`
2. プロジェクト設定 → **Apps** → **＋ New**
3. **App Store** を選択
   - App name: `wanote (iOS)` / **Bundle ID: `jp.wanote.app`**
   - **In-App Purchase Key**: A-3 の `.p8` をアップロードし、
     **Issuer ID** と **Key ID** を貼り付け
4. 再度 **＋ New** → **Play Store**
   - App name: `wanote (Android)` / **Package name: `jp.wanote.app`**
   - **Service Account credentials JSON**: G-3 の JSON をアップロード

## R-2. 商品を取り込む

1. 左メニュー **Product catalog** → **Products**
2. **＋ New** → iOS アプリを選び、4つの商品IDを登録
3. Android アプリでも同じ4つを登録
   - 定期購入は `premium_monthly:monthly` のように
     「プロダクトID:基本プランID」で表示されることがあります。それを選択

**合計8件（iOS 4件＋Android 4件）**になります。

## R-3. Entitlement を作る（ここが一番重要です）

1. **Product catalog** → **Entitlements** → **＋ New**
2. **Identifier: `premium`** / 説明: `広告非表示・AI無制限・レポート`
3. **Attach** で、次の**4件だけ**を紐付ける
   - iOS `premium_monthly` / iOS `premium_yearly`
   - Android `premium_monthly` / Android `premium_yearly`

> ❌ **チケット2種は絶対に紐付けないでください。**
> 紐付けると、チケットを1枚買っただけで**永久にプレミアム**になります。
> チケットの枚数はアプリ側が別にカウントしています。

## R-4. Offering（売り場）を作る

1. **Product catalog** → **Offerings** → **＋ New**
2. Identifier: `default` / Description: `プラン画面`
3. ★ **作成後、この Offering を「Current」（既定）にしてください**
   - アプリは **Current の Offering だけ**を読みます。忘れると
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
   - iOS 用（`appl_` で始まる） / Android 用（`goog_` で始まる）

> このキーは**アプリに埋め込まれる公開キー**で、秘密情報ではありません。

## R-6. シークレットキー（サーバー用）

キャンペーンコードでプレミアムを付与する機能がサーバー側にあり、**秘密鍵**を使います。

1. 同じ **API keys** の画面で **Secret API key** を作成（`sk_` で始まる）
2. 🔒 **この鍵は私には渡さないでください。** 下をPMご自身で実行してください

```bash
cd C:/Dev/wanote/functions && npx wrangler secret put REVENUECAT_SECRET_KEY
```

---

# 第4部　アプリへ反映して再アップロード

## 4-1. 公開キーを設定ファイルへ（PM作業）

`C:\Dev\wanote\config\prod.json` を、次のように書き換えます（`xxx` を実際の値に）。

```json
{
  "AI_BACKEND_BASE_URL": "https://wanote-functions.wanote-app-reply.workers.dev",
  "REVENUECAT_API_KEY_IOS": "appl_xxxxxxxxxxxxxxxx",
  "REVENUECAT_API_KEY_ANDROID": "goog_xxxxxxxxxxxxxxxx"
}
```

> 商品IDと Entitlement は、**この手順書どおりの名前なら追記不要**です
> （アプリ側の既定値と一致しています）。

## 4-2. 再ビルドと再アップロード

書き換えたら教えてください。こちらで AAB を作り直します。
できたら第0部の 0-4 と同じ手順で、内部テストへ新しいリリースとして上げてください。

## 4-3. Codemagic（iOS用）

環境変数 `REVENUECAT_API_KEY_IOS` / `REVENUECAT_API_KEY_ANDROID` を
`wanote_ios` グループに追加してください（**Secure にチェック**）。
※ ビルド側で受け取る処理は、キーが用意でき次第こちらで対応します。

---

# 第5部　テスト購入（★翌日以降）

## 課金は発生しません

- **Android**: G-4 のライセンステストに登録済みのアカウント ＋ 内部テストに参加
- **iOS**: A-4 の Sandbox アカウントでサインイン

**どちらも実際の請求は発生しません。**
ただし**未登録のアカウントで買うと実際に課金されます。**

## 最初の判定点

**設定 → プランをアップグレード** が「準備中です」から
**商品4つの一覧**に変われば、設定が効いています。

## うまくいかないときの見分け方

| 症状 | 原因 |
|---|---|
| 「準備中です」のまま | 公開APIキーが未設定、またはビルドに含まれていない |
| 「ご利用いただけるプランがありません」 | Offering が **Current** になっていない |
| 一部の商品だけ出ない | ストア側でその商品が「有効化」されていない |
| 商品名がストアの名前で出る | 商品IDが表と違う（アプリが名前を判別できていない） |
| 購入できたのに広告が消えない | Entitlement `premium` に商品が紐付いていない |
| Invalid Play Store credentials | 36時間の反映待ち。時間をおいて再確認 |

---

# チェックリスト

## 今日やること（最低ライン）

- [ ] 0-1 アップロード鍵 `.jks` を作成し、**バックアップ**
- [ ] 0-2 `android/key.properties` を作成
- [ ] 0-3 AAB をビルド（私）
- [ ] 0-4 内部テストへアップロード
- [ ] 0-5 テスターを登録
- [ ] G-1 定期購入2つ（基本プラン**有効化**まで）
- [ ] G-2 アプリ内アイテム2つ（**有効化**まで）
- [ ] G-3 サービスアカウント ＋ Play Console で権限付与 ← **36時間タイマー開始**
- [ ] G-4 ライセンステストに自分を登録
- [ ] A-1 Apple サブスク2つ（同一グループ）
- [ ] A-2 Apple 消耗型2つ
- [ ] A-3 In-App Purchase キー（.p8 / キーID / Issuer ID）
- [ ] A-4 Sandbox テスター
- [ ] R-1〜R-5 RevenueCat 一式（Entitlement は**サブスク4件だけ**、Offering は **Current**）
- [ ] R-6 Worker に `REVENUECAT_SECRET_KEY`（PMが実行）
- [ ] 4-1 `config/prod.json` に公開キー2つ
- [ ] 4-2 再ビルド（私）＋再アップロード
- [ ] 4-3 Codemagic に公開キー2つ

## 翌日以降

- [ ] 第5部 テスト購入（Android / iOS）

---

# 出典

- RevenueCat Quickstart — https://www.revenuecat.com/docs/getting-started/quickstart
- Entitlements — https://www.revenuecat.com/docs/getting-started/entitlements
- Products / Offerings — https://www.revenuecat.com/docs/offerings/products-overview
- Google Play service credentials — https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials
- Google Play Billing Setup (2026) — https://revenuecat.github.io/codelabs/google-play.html
- Play Billing Library の統合 — https://developer.android.com/google/play/billing/integrate
