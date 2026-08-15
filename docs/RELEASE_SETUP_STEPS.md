# 出荷準備の手順（署名 → 課金 → 広告）

作成: 2026-08-15
前提: **Google Play / Apple Developer とも登録完了（8/15）**

**このファイルは PM の作業手順書です。** 実機での動作確認は
[VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md) 側で、**並行して**
進められます。両者は独立しています。

---

# 全体像

**順番に意味があります。** 上が終わらないと下が始められません。

```
① 署名鍵の作成                    ← 私が手順を出す／鍵はPMのみ
     ↓
② Play Console でアプリ作成・支払いプロファイル
     ↓
③ AAB を内部テストにアップロード   ← ①が無いと不可
     ↓
④ アプリ内商品を4つ登録            ← ③が無いと項目が出ない
     ↓
⑤ RevenueCat に接続・エンタイトルメント設定
     ↓
⑥ アプリに RevenueCat のキーを入れて再ビルド → 課金が動く
```

```
AdMob は独立（いつでも着手可）
  AdMob 登録 → 広告ユニット作成 → IDを2箇所に反映 → 再ビルド
```

```
Apple 側も独立（Androidと並行可）
  Bundle ID 登録 → Sign in with Apple 有効化 → Firebase 側設定
```

---

# ⚠️ 私に送ってはいけないもの

| | 置き場所 |
|---|---|
| アップロード鍵（`.jks`）とパスワード | **PMの手元のみ**。リポジトリ外＋別媒体にバックアップ |
| Play のサービスアカウントJSON | **RevenueCat の管理画面に直接**アップロード |
| App Store Connect APIキー（`.p8`） | Codemagic の管理画面に直接 |
| RevenueCat の Secret Key | Worker に `wrangler secret put` |

**RevenueCat の公開SDKキー（`appl_` / `goog_`）と広告ユニットIDは秘密では
ありません。** アプリに埋め込まれる前提の値なので、`config/prod.json` に
書いていただいて構いません（このファイルは `.gitignore` 済み）。

---

# ① 署名鍵の作成

**失うと、このアプリを二度と更新できません。** 最初に、確実にやります。

## 1-1. 鍵を作る

**リポジトリの外**で実行してください（例では `C:\Users\<user>\keys`）。

```
keytool -genkey -v -keystore C:\Users\%USERNAME%\keys\wanote-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wanote
```

聞かれる項目：

| 質問 | 入れるもの |
|---|---|
| キーストアのパスワード | **控える。忘れると詰みます** |
| 姓名 / 組織 / 市 / 州 / 国コード | 任意。国コードは `JP` |
| 鍵のパスワード | キーストアと同じで可（Enterで流用） |

## 1-2. バックアップ

- [ ] `wanote-upload.jks` を**別媒体**にコピー（USB・外部ドライブ等）
- [ ] パスワードをパスワードマネージャに保存
- [ ] 🔴 **`C:\Dev\wanote` の中に置かない**（Gitに入る事故を防ぐため）

## 1-3. `key.properties` を作る

`C:\Dev\wanote\android\key.properties` に以下を作成してください。
**このファイルは `.gitignore` 済みです。**

```
storePassword=<キーストアのパスワード>
keyPassword=<鍵のパスワード>
keyAlias=wanote
storeFile=C:/Users/<ユーザー名>/keys/wanote-upload.jks
```

> パスは **`/` 区切り**で書いてください（`\` はエスケープが必要）。

## 1-4. こちらの作業

**`key.properties` を置いたら教えてください。**
`build.gradle.kts` にリリース署名の読み込みを追加し、署名付きAABが
出せる状態にします（10分程度）。**鍵とパスワードは見ません。**

---

# ② Play Console：アプリ作成

- [ ] アプリを作成
  - アプリ名: **wanote**
  - デフォルトの言語: 日本語
  - アプリ / ゲーム: **アプリ**
  - 無料 / 有料: **無料**（アプリ内課金あり）
- [ ] パッケージ名が **`jp.wanote.app`** になっていることを確認
      （🔴 **後から変更できません**）
- [ ] 「収益化」→ **支払いプロファイル**を設定
      （銀行口座・税務情報。審査に数日かかることがあります）

> **支払いプロファイルは早めに。** ここが未完だと④の商品登録ができません。

---

# ③ AAB を内部テストにアップロード

①が終わっていれば、こちらでビルドします。**声をかけてください。**

```
flutter build appbundle --release --dart-define-from-file=config/prod.json
```

- [ ] Play Console →「テスト」→「内部テスト」→ 新しいリリースを作成
- [ ] `build/app/outputs/bundle/release/app-release.aab` をアップロード
- [ ] リリースノートを記入して保存（公開はまだ不要）

> この時点では**プライバシーポリシーURL等の未入力**で弾かれる場合が
> あります。その場合は⑥の並行作業を先に片付けてください。

---

# ④ アプリ内商品を4つ登録

**「収益化」→「商品」から登録します。**
IDは**コードと一致していないと動きません**（[`product_ids.dart`](../lib/features/billing/domain/product_ids.dart)）。

## 定期購入（サブスクリプション）

| 商品ID | 名称 | 期間 |
|---|---|---|
| `premium_monthly` | wanote プレミアム（月額） | 1か月 |
| `premium_yearly` | wanote プレミアム（年額） | 1年 |

**特典**: 広告非表示 ／ AI相談 無制限 ／ AI健康レポート

## アプリ内アイテム（消耗型）

| 商品ID | 名称 | 内容 |
|---|---|---|
| `ai_tickets_5` | AI相談チケット 5回分 | 消耗型 |
| `ai_tickets_15` | AI相談チケット 15回分 | 消耗型 |

## 金額について（PM決定事項）

**仕様書に価格の記載がないため、未決定です。** 判断材料を出します。

原価は極めて低く、**価格は原価ではなく「無料枠との差」で決まります。**
AI1回あたり約0.5〜0.8円なので、月100回使われても100円未満です。

参考として、この構成なら次のあたりが自然です。

| | 案 | 考え方 |
|---|---|---|
| 月額 | **480〜680円** | 広告非表示＋AI無制限。国内の同種アプリの相場帯 |
| 年額 | **月額×10か月分** | 2か月無料相当。年額への誘導は定番 |
| チケット5回 | **160〜240円** | 「1回あたり月額より割高」にするのが要点 |
| チケット15回 | **5回×2.5倍程度** | まとめ買いに割安感を出す |

🔴 **チケットが月額より割安になると、サブスクが売れなくなります。**
「たくさん使うなら月額の方が得」と一目で分かる関係にしてください。

無料5回は**AI相談と給餌量相談の共用**なので、月に何度も相談する人は
すぐ上限に当たります。そこがチケットとサブスクの入口です。

- [ ] 4商品を登録
- [ ] 価格を設定（**日本以外の国の価格は自動換算で可**）
- [ ] 各商品を **有効化**

---

# ⑤ RevenueCat の設定

- [ ] RevenueCat にサインアップ（GitHubアカウントで可）
- [ ] プロジェクト **wanote** を作成
- [ ] **Play Store アプリを追加**
  - パッケージ名: `jp.wanote.app`
  - 🔴 **サービスアカウントJSON**をアップロード
    （Google Cloud で作成し Play Console で権限付与。RevenueCat の
    画面に手順リンクがあります）
- [ ] 商品を4つインポート（④で登録したIDが出てきます）

## エンタイトルメント

**ここが要です。コードは `premium` という名前を見ています。**

- [ ] エンタイトルメント **`premium`** を作成
- [ ] `premium_monthly` と `premium_yearly` の**両方**を紐付ける
- [ ] 🔴 **`ai_tickets_5` / `ai_tickets_15` は紐付けない**
      （消耗型はエンタイトルメントではなく、購入イベントとして
      チケット残数に加算する設計です）

## Offering

- [ ] Offering を1つ作り、4商品をパッケージとして入れる
- [ ] **Current** に設定

## APIキーの取得

- [ ] **Android の公開SDKキー**（`goog_` で始まる）を控える
- [ ] iOS 分（`appl_`）は App Store Connect 接続後に取得

---

# ⑥ アプリに反映して再ビルド

`config/prod.json` に追記してください（**秘密ではない値です**）。

```json
"REVENUECAT_API_KEY_ANDROID": "goog_xxxxxxxxxxxx",
"REVENUECAT_API_KEY_IOS": "appl_xxxxxxxxxxxx"
```

- [ ] 追記したら**声をかけてください**。ビルドして実機に入れます
- [ ] プラン画面に**実際の価格が表示される**ことを確認
- [ ] テスト購入（Play Console の**ライセンステスト**に自分を登録すると
      課金されずに購入できます）
- [ ] 購入後、**広告が消える**
- [ ] チケット購入後、**残回数が増える**

---

# ⑦ AdMob（①〜⑥と並行可）

**いまは Google のテストIDです。このまま出すと収益ゼロで、
アプリ側は何も警告しません。**

- [ ] AdMob にサインアップ
- [ ] アプリを追加（Android / iOS それぞれ）
      - 「アプリストアに公開済みですか」→ **いいえ**（後で紐付け可）
- [ ] 🔴 **アプリID**（`ca-app-pub-XXXX~XXXX`、区切りが `~`）を控える
- [ ] 広告ユニットを作成
      - **インタースティシャル**（Android / iOS）
      - **バナー**（Android / iOS）
      - ユニットID は区切りが `/` です（アプリIDと形が違います）

## 反映先が2種類あります

| 値 | 入れる場所 |
|---|---|
| 広告**ユニット**ID（4つ） | `config/prod.json` |
| 広告**アプリ**ID（2つ） | 🔴 **`AndroidManifest.xml` と `Info.plist`**（コード側。私が反映します） |

アプリIDは `--dart-define` では渡せないため、**ファイルに直接書く必要が
あります**（[`AndroidManifest.xml:64`](../android/app/src/main/AndroidManifest.xml)
／ [`Info.plist:82`](../ios/Runner/Info.plist)）。

- [ ] **6つのIDを教えてください。**（秘密ではありません）
      ユニットID4つは私が `config/prod.json` に、アプリID2つは
      コードに反映します

## SKAdNetwork（iOS）

- [ ] AdMob の管理画面から **SKAdNetworkItems** の一覧を取得
- [ ] 🔴 **推測では書けません。** AdMobが出す一覧をそのまま渡してください

---

# ⑧ Apple 側（Androidと並行可）

- [ ] Apple Developer → Identifiers で **`jp.wanote.app`** を登録
- [ ] 🔴 **Sign in with Apple** の capability を有効化
      （無いと **iOS はリジェクトされます**）
- [ ] Firebase コンソール → Authentication → **Apple** を有効化
      - Services ID / Team ID / Key ID / `.p8` の登録が要ります
- [ ] App Store Connect でアプリを作成（Bundle ID: `jp.wanote.app`）
- [ ] 同じ4商品を App Store Connect 側にも登録

---

# ⑨ その他の出荷前提

- [ ] **プライバシーポリシーの公開**
      `site/privacy-ja.html` / `privacy-en.html` を Cloudflare Pages へ。
      **両ストアで公開URLが必須**
- [ ] **`api.wanote.jp`** の設定
      🔴 バックエンドURLは**ビルド時に埋め込まれ、出荷後に変更できません**。
      `*.workers.dev` のまま出すと、後でCloudflareのアカウント名や
      Worker名を変えられなくなります
- [ ] **アプリアイコン**の差し替え（PM作成待ち）
- [ ] **ストア掲載文**の見直し（実機確認の完了後）

---

# 日程の制約（最重要）

**Google Play が律速です。**

個人アカウントの新規アプリには **「12人以上が14日間連続でテストに参加」**
が課されます。**14日は短縮できません。**

| | 所要 |
|---|---|
| クローズドテスト | **14日（固定）** |
| 製品版アクセスの審査 | 数日〜（変動） |
| アプリ審査 | 数日 |

**9月上旬までにクローズドテストを開始**しておくのが安全です。
**テスター12人の確保**（家族・友人可）も並行して進めてください。
ここが埋まらないと、アプリが完成していても出せません。

詳細は [CLOSED_TEST_GUIDE.md](CLOSED_TEST_GUIDE.md)。

---

# 次にやること（推奨順）

| | 作業 | 担当 |
|---|---|---|
| 1 | **署名鍵の作成**（①） | PM |
| 2 | `key.properties` 配置 → **連絡** | PM → 私 |
| 3 | リリース署名の組み込み | 私 |
| 4 | Play Console アプリ作成・支払いプロファイル（②） | PM |
| 5 | AdMob 登録・6つのID取得（⑦） | PM |
| 6 | 実機での確認（[VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md)） | PM・**並行可** |

**②の支払いプロファイルは審査に数日かかることがあります。**
先に出しておくと、後の工程が詰まりません。
