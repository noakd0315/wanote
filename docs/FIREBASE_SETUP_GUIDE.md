# Firebase の設定手順（詳細版）

作成: 2026-08-13

**所要: 30〜60分。** コンソール画面での作業と、PCでのコマンド実行が混ざります。

**先に結論**: コンソールで手作業する範囲は思ったより少なく、
**アプリの登録は `flutterfire configure` というコマンドが自動でやってくれます。**
手作業は「プロジェクト作成」「機能の有効化」「サービスアカウント」の3つだけです。

---

## 事前に確認済みのこと

| | |
|---|---|
| Android の applicationId | **`jp.wanote.app`**（設定済み） |
| iOS の Bundle ID | **`jp.wanote.app`**（設定済み） |
| Firebase CLI | `npx firebase-tools` で使える（インストール不要） |
| FlutterFire CLI | **未インストール**（手順1で入れます） |

**AndroidとiOSで同じIDです。** 登録時に間違えないよう、コピペしてください。

---

## 手順1：FlutterFire CLI を入れる（**実施済み・2026-08-13**）

```bash
dart pub global activate flutterfire_cli
```

→ **インストール済み（1.4.1）**。

### ⚠️ `flutterfire` は PATH に入りません

インストール先の `Pub\Cachein` は既定で PATH に含まれないため、
**`flutterfire configure` と打つと「認識されません」というエラーになります**
（実際に発生しました）。

**PATH を触らずに使えるコマンドがこちらです。以降はこちらを使ってください:**

```bash
dart pub global run flutterfire_cli:flutterfire configure
```

短い名前で呼びたい場合のみ、PowerShell で一度だけ PATH に追加し、
**PowerShell を開き直して**ください（任意）。

---

## 手順2：Firebase プロジェクトを作る（コンソール・5分）

https://console.firebase.google.com/ を開き、**プロジェクトを作成**。

| 項目 | 入力 |
|---|---|
| プロジェクト名 | `wanote`（自由。IDは自動で `wanote-xxxxx` のようになります） |
| Google アナリティクス | **オフでOK** |

> **アナリティクスをオフにする理由**: このアプリは解析SDKを一切入れて
> いません（プライバシーポリシーにも「解析SDKは組み込んでいない」と
> 明記しています）。有効にすると申告内容と食い違います。

**ここでは「アプリを追加」はしないでください。** 次の手順が自動でやります。

> ℹ️ **この画面にリージョン（ロケーション）の設定はありません。それで正常です。**
> リージョンを聞かれるのは **手順4-2 で Firestore を作るとき**が最初です。
> プロジェクト作成の段階では出てこないので、探さなくて大丈夫です。

---

## 手順3：アプリを自動登録する（PC作業・5分）

```bash
cd C:\Dev\wanote
npx firebase-tools login
```

ブラウザが開くので、手順2で使った Google アカウントで許可します。

続けて（**PATH 不要の形**）:

```bash
dart pub global run flutterfire_cli:flutterfire configure
```

対話形式で聞かれます:

| 質問 | 答え方 |
|---|---|
| どのプロジェクトを使うか | 手順2で作った `wanote-xxxxx` を選ぶ |
| どのプラットフォームか | **android と ios にチェック**（web は不要。スペースで選択、Enterで確定） |
| Android package name | `jp.wanote.app` が自動で入ります。**そのままEnter** |
| iOS bundle ID | `jp.wanote.app` が自動で入ります。**そのままEnter** |

**これだけで以下が全部done になります:**

- Firebase 側に Android アプリと iOS アプリが登録される
- `android/app/google-services.json` が配置される
- `ios/Runner/GoogleService-Info.plist` が配置される
- `lib/firebase_options.dart` が生成される

> **この3ファイルは `.gitignore` 済み**なので、Gitには入りません。
> PCが変わったら `flutterfire configure` をやり直せば再生成されます。

---

## 手順4：機能を有効化する（コンソール・10分）

コンソールに戻り、左メニューから3つ設定します。

### 4-1. Authentication（サインイン）

1. 左メニュー **構築 → Authentication** → 中央の **「始める」** を押す
   > ⚠️ **「始める」を押すまでタブは1つも表示されません。**
   > 「Sign-in method が見当たらない」の原因はほぼこれです。
2. **「ログイン方法」** タブ
   > 日本語表示では **「Sign-in method」ではなく「ログイン方法」**です。
   > （タブは「ユーザー」「ログイン方法」「テンプレート」…の並び）
3. **「メール / パスワード」** を選び、一番上の **「有効にする」** をオン → 保存
   > 2つ目の「メールリンク（パスワードなしでログイン）」は**オフのまま**でOK

> **Google / Apple サインインは今はやりません。**
> Apple は Apple Developer Program が必要（申請待ち）で、Google も
> 後から追加できます。**メール/パスワードだけで実機テストは通ります。**

### 4-2. Firestore Database

1. 左メニュー **構築 → Firestore Database** →「データベースを作成」
2. **ロケーション**: **`asia-northeast1`（東京）**
   ← **リージョンを選ぶのはここが最初**です
3. モード: **本番環境モード**（ルールは後で私の書いたものに差し替えます）

> 🔴 **ロケーションは後から変更できません。** 日本のユーザ向けなので
> 東京にしてください。
>
> 「本番環境モード」を選ぶと最初はすべて拒否のルールになりますが、
> 手順6で正しいルールに差し替えるので問題ありません。

### 4-3. Storage（写真・証明書の保存先）

1. 左メニュー **構築 → Storage** →「始める」
2. ロケーションは **Firestore と同じ `asia-northeast1`**
3. モード: **本番環境モード**

> ⚠️ **ここで「Blaze プラン（従量課金）への切り替え」を求められることが
> あります。** 新しいプロジェクトでは求められるのが普通です。
>
> **カード登録が必要ですが、無料枠の範囲なら請求は0円です。**
> Storage の無料枠は 5GB。証明書と写真だけなら当面まったく届きません。
>
> 心配であれば、Google Cloud の**予算アラート**を月1,000円などに
> 設定しておくと安心です。

---

## 手順5：サービスアカウントの鍵（コンソール・5分）

Worker（バックエンド）が Firestore を読むために必要です。

1. 左上の**歯車アイコン → プロジェクトの設定**
2. **サービス アカウント** タブ
3. **新しい秘密鍵の生成** → JSONファイルがダウンロードされます

> 🔴 **このJSONは私に渡さないでください。** 中身は Firestore への
> フルアクセス権そのものです。Gitにも入れないでください。

このJSONを開くと、以下の値が入っています（手順7で使います）:

```json
{
  "project_id": "wanote-xxxxx",
  "client_email": "firebase-adminsdk-xxxxx@wanote-xxxxx.iam.gserviceaccount.com",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
}
```

---

## 手順6：セキュリティルールを反映する（PC作業・2分）

**これをやるまで、アプリはデータを一切読み書きできません**
（手順4で「本番環境モード」＝全拒否にしたため）。

```bash
cd C:\Dev\wanote
npx firebase-tools deploy --only firestore:rules,storage
```

> ここでデプロイされるのは、**すでに書いてありテスト77件が通っている
> ルール**です（`firestore.rules` / `storage.rules`）。
> 「他人のペットの記録は読めない」「お知らせは誰でも読めるが誰も書けない」
> といった内容です。

---

## 手順7：Worker のシークレット（PC作業・10分）

Cloudflare の設定が済んでから行ってください（未了なら後回しでOK）。

```bash
cd C:\Dev\wanote\functions
npx wrangler secret put FIREBASE_PROJECT_ID
npx wrangler secret put FIREBASE_CLIENT_EMAIL
npx wrangler secret put FIREBASE_PRIVATE_KEY
```

それぞれ手順5のJSONの `project_id` / `client_email` / `private_key` を
貼り付けます。

> 🔴 **`private_key` は改行を `\n` という2文字に置換して、1行にして**
> 貼り付けてください。JSONファイル内では既に `\n` として書かれているので、
> **JSONを開いて `private_key` の値をそのままコピー**すれば大丈夫です
> （前後の `"` は除く）。

---

## ✅ 終わったら教えてください

以下を確認して、結果だけ教えてください（**ファイルの中身は不要です**）:

- [ ] `C:\Dev\wanote\lib\firebase_options.dart` が存在する
- [ ] `C:\Dev\wanote\android\app\google-services.json` が存在する
- [ ] `C:\Dev\wanote\ios\Runner\GoogleService-Info.plist` が存在する
- [ ] **プロジェクトID**（`wanote-xxxxx`）
- [ ] 手順6のデプロイが成功した
- [ ] Blaze プランに切り替えたかどうか

**受け取ったら私がやること:**

1. `main.dart` を実プロジェクト対応にする
   （現在は**常にエミュレータ用の設定**を読んでいます。
   `CLOUD_PHASE_TASKS.md` A-2。**これをやらないと実プロジェクトに繋がりません**）
2. Android 実機ビルドの手順書を作る
3. 実機での確認項目リストを作る

---

## つまずいたときは

| 症状 | 原因と対処 |
|---|---|
| **`flutterfire` が認識されない** | **既知**。PATH に入らないため。`dart pub global run flutterfire_cli:flutterfire configure` を使う（手順1参照） |
| `flutterfire configure` でプロジェクトが出ない | `npx firebase-tools login` のアカウントが違う。`npx firebase-tools logout` して入り直す |
| package name が違う値で入る | **`jp.wanote.app` に手入力**してください。ここが違うと実機で認証が通りません |
| Storage で課金を求められる | 想定内です（手順4-3の注記）。無料枠内なら請求0円 |
| デプロイで権限エラー | `npx firebase-tools use wanote-xxxxx` でプロジェクトを明示してから再実行 |

**どこで止まっても、画面に出ているメッセージをそのまま貼っていただければ
こちらで判断します。**
