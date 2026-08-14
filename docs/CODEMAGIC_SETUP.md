# Codemagic の設定手順（iOSビルド用）

作成: 2026-08-14

**目的**: Mac を用意せずに iOS のビルドと TestFlight 配信を行う。
`flutter build ipa` は Xcode を必要とし、Windows では実行できないため。

`codemagic.yaml` は**リポジトリに作成済み**です。

---

## 🔴 最初のブロッカー：リモートリポジトリがありません

**確認したところ、`C:\Dev\wanote` に git のリモートが設定されていません。**

```
$ git remote -v
（空）
```

**Codemagic は接続されたリポジトリからビルドします。**
GitHub / GitLab / Bitbucket のいずれかに置く必要があります。

### やること

1. **GitHub アカウントを作成**（既にあればそれで可）
   https://github.com/signup
2. **プライベートリポジトリを作成**（例: `wanote`）
   > 🔴 **必ず Private にしてください。** 秘密情報はコミットしていませんが、
   > 製品コードそのものです
3. PC から push

```bash
cd C:\Dev\wanote
git remote add origin https://github.com/<ユーザー名>/wanote.git
git branch -M main
git push -u origin main
```

> **コミット済みの内容に秘密情報は含まれていません。**
> `firebase_options.dart` / `google-services.json` /
> `GoogleService-Info.plist` / `key.properties` / `*.jks` /
> `config/*.json` はすべて gitignore 済みです。

---

## 2つのワークフローに分けてあります

| 名前 | 内容 | 必要なもの |
|---|---|---|
| **`verify`** | `flutter analyze` と `flutter test` | **なし。今日から使えます** |
| `ios` | ビルド → TestFlight | Apple Developer Program |

**分けた理由**: 1本にすると、Apple の審査が下りるまで**毎コミットで
CI が失敗し続けます**。`verify` だけなら、リポジトリを繋いだ瞬間から
役に立ちます。

> `verify` は `firebase_options.dart` が無い環境でも通るよう、
> **CI 内でダミーを生成**します。実行すると例外を投げるだけの
> 中身なので、**誤ってどこかに繋がることはありません。**

---

## 手順

### A. Codemagic アカウント（5分・今すぐ可）

https://codemagic.io/signup

- GitHub アカウントでサインアップ
- リポジトリを接続
- **`verify` ワークフローがすぐ動きます**

### B. iOS 用の設定（**Apple Developer Program 承認後**）

#### B-1. App Store Connect の API キー

1. https://appstoreconnect.apple.com/access/integrations/api
2. **「App Store Connect API」→ キーを生成**
3. アクセス権は **App Manager** で十分です
4. **`.p8` ファイルは一度しかダウンロードできません。** 保管してください
5. 次の3つを控える: **Issuer ID / Key ID / .p8 ファイル**

#### B-2. Codemagic に登録

Codemagic → **Teams → Integrations → Apple Developer Portal**
に上記3つを登録します。

これで**証明書とプロビジョニングプロファイルは Codemagic が自動管理**します。
Mac なし運用で最も厄介な署名まわりを任せられるのが、この構成の理由です。

#### B-3. 環境変数グループ `wanote_ios`

Codemagic → **Environment variables** で、グループ名 **`wanote_ios`** を
作り、以下を登録します（**すべて Secure にチェック**）。

| 変数名 | 中身 |
|---|---|
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | `ios/Runner/GoogleService-Info.plist` を base64 化したもの |
| `FIREBASE_OPTIONS_DART_BASE64` | `lib/firebase_options.dart` を base64 化したもの |

base64 化のコマンド（PowerShell）:

```bash
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Dev\wanote\ios\Runner\GoogleService-Info.plist")) | Set-Clipboard
```

```bash
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Dev\wanote\lib\firebase_options.dart")) | Set-Clipboard
```

> **なぜ base64 か**: これらは gitignore してあるのでリポジトリに無く、
> かつ Windows からは Xcode プロジェクトへ登録できません。
> CI 側で復元するのが現実的な回避策です。
>
> **中身は秘密情報ではありません**（クライアントに埋め込まれる公開値）が、
> 環境変数は Secure にしておいてください。

#### B-4. `config/prod.json` の扱い（要検討）

`ios` ワークフローは `--dart-define-from-file=config/prod.json` を
使いますが、**このファイルも gitignore 済み**です。

**同じ方法で環境変数から復元するのが素直です。** 着手時に対応します。

---

## Apple 側で別途必要なもの

| | 状況 |
|---|---|
| Apple Developer Program（年99USD） | 🔴 未申請 |
| App Store Connect でアプリ作成（`jp.wanote.app`） | 🔴 未 |
| **Sign in with Apple の有効化** | 🔴 **未。Apple の必須要件** |
| Firebase の Apple サインイン設定 | 🔴 未 |
| `SKAdNetworkItems`（Info.plist） | 🔴 未（AdMob 登録後） |

> 🔴 **Sign in with Apple は必須です。** 「他社のログインを提供するなら
> Sign in with Apple も提供する」という Apple のルールがあり、
> **無いとリジェクトされます。** アプリ側の実装は済んでいますが、
> Apple Developer と Firebase 双方の設定が未了です。

---

## 進め方の提案

**A（Codemagic アカウント＋リポジトリ接続）だけ先にやっておく**と、
Apple の審査を待つ間も `verify` が全コミットで回り、
**壊れたまま気づかない状態を防げます。**

今日見つかった `AndroidManifest.xml` の不正XMLは、
**Android ビルドを実行するまで誰も気づけませんでした。**
CI があれば早く分かった類の問題です。

> ただし `verify` は analyze とテストのみで、**Android ビルドはしません**
> （Linux マシンで Android ビルドも可能なので、必要なら追加できます）。
> **同じ取りこぼしを防ぐなら、Android ビルドも CI に足す価値があります。**
> ご希望があれば追加します。
