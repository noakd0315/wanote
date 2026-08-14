# 設定手順：Anthropic → Firebase の鍵 → Cloudflare

作成: 2026-08-14

**合計 50〜60分。** 3つに分かれているので、**細切れの時間でも進められます。**

この順番にする理由は、**Cloudflare の作業中に必要な値が全部手元に揃っている**
ようにするためです。順番を入れ替えると、Cloudflare の途中で
Anthropic のコンソールへ取りに行くことになります。

| | 所要 | 中断できるか |
|---|---|---|
| **A. Anthropic** | 15分 | ✅ ここで止めてOK |
| **B. Firebase の鍵** | 5分 | ✅ ここで止めてOK |
| **C. Cloudflare** | 30分 | ⚠️ C-3 以降は一気にやる方が楽 |

**これが終わると、AI機能（相談・レポート・OCR）とアカウント削除が動きます。**

---

# A. Anthropic Console（15分）

https://console.anthropic.com/

## A-1. アカウント作成

Google アカウントでのサインアップが使えます。
**`wanote.app.reply@gmail.com` を使うと、他のサービスと揃って管理が楽です。**

## A-2. 支払い方法の登録

左メニュー **Billing** → クレジットカードを登録。

**前払い式（クレジットを購入する形）です。** 最小額（$5程度）で始めて
構いません。仕様書9章の試算では **AI相談1回あたり 0.3〜0.5円程度**なので、
テストには十分すぎます。

## A-3. 🔴 使用上限を設定する（重要）

**Billing → Limits** で **月間の上限**を低めに設定してください。

> **理由**: 実装にはサーバー側のレート制限（1人あたりの回数上限）を
> 入れてありますが、**アカウント数そのものには上限がありません**。
> 想定外の使われ方をしたときの最後の防波堤になります。
> **$10 / 月**あたりから始めることを推奨します。

## A-4. APIキーを発行

左メニュー **API Keys** → **Create Key**

- 名前: `wanote-worker` など分かる名前
- **表示されるキーは一度しか見られません。** メモ帳などに一時的に
  貼り付けておいてください（手順 C-5 で使います）

> 🔴 **このキーは私に渡さないでください。** C-5 でPMご自身が Cloudflare に
> 直接設定します。**Gitにも、設定ファイルにも入れません。**

### ✅ Aの完了条件

- [ ] APIキーを発行して控えた
- [ ] 使用上限を設定した

---

# B. Firebase のサービスアカウント鍵（5分）

Worker が Firestore を読み書きするために必要です。

## B-1. 鍵をダウンロード

1. https://console.firebase.google.com/project/wanote-7dca0/settings/serviceaccounts/adminsdk
2. **「新しい秘密鍵の生成」** → 確認ダイアログで **「キーを生成」**
3. JSONファイルがダウンロードされます

## B-2. 中身から3つの値を控える

JSONをメモ帳などで開くと、こうなっています:

```json
{
  "type": "service_account",
  "project_id": "wanote-7dca0",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@wanote-7dca0.iam.gserviceaccount.com",
  ...
}
```

手順 C-5 で使うのは次の3つです:

| 設定名 | JSONのどこ |
|---|---|
| `FIREBASE_PROJECT_ID` | `project_id` の値 → **`wanote-7dca0`** |
| `FIREBASE_CLIENT_EMAIL` | `client_email` の値 |
| `FIREBASE_PRIVATE_KEY` | `private_key` の値 |

> 🔴 **`private_key` は `"` で囲まれた中身をそのままコピー**してください。
> **`\n` は改行に直さず、`\n` という2文字のまま**にします。
> JSONの中では既にそうなっているので、**素直にコピーすれば正しい形**です。
> （前後の `"` は含めません）

> 🔴 **このJSONファイルは私に渡さないでください。** Firestore への
> フルアクセス権そのものです。`C:\Dev\wanote` の中に置かないでください
> （誤ってコミットされるのを防ぐため）。ダウンロードフォルダのままで結構です。

### ✅ Bの完了条件

- [ ] JSONをダウンロードした
- [ ] 3つの値の場所が分かった

---

# C. Cloudflare（30分）

https://dash.cloudflare.com/sign-up

## C-1. アカウント作成

メールアドレスとパスワードで作成。
**`wanote.app.reply@gmail.com` を推奨**（他と揃えるため）。

> **この時点ではドメイン（`wanote.jp`）を追加しなくて構いません。**
> DNSの移管は反映に時間がかかるので、後日で大丈夫です。
> **Worker のデプロイだけならドメイン不要**です。

## C-2. Workers を有効化

左メニュー **Compute (Workers)** → 案内に従って有効化。

- プランは **Free** を選んでください
- サブドメイン名を聞かれたら、`wanote` など好きな名前でOK
  （`https://xxx.wanote.workers.dev` の `wanote` の部分になります）

## C-3. PCから Cloudflare にログイン

PowerShell で:

```bash
cd C:\Dev\wanote\functions
npx wrangler login
```

ブラウザが開くので **Allow** を押します。

> **Firebase のときと同じ注意点です。** ブラウザに別の Cloudflare
> アカウントでログイン済みだと、そのまま通ってしまうことがあります。
> **表示されたアカウントが正しいか確認**してください。

確認:

```bash
npx wrangler whoami
```

## C-4. まず一度デプロイしてみる

```bash
npx wrangler deploy
```

**成功すると `https://wanote-functions.xxxxx.workers.dev` のような
URLが表示されます。このURLを控えてください**（私に渡していただきます）。

> ⚠️ **ここで止まる可能性がある箇所（要確認事項）**
>
> このアプリはレート制限に **Durable Objects** を使っています
> （`wrangler.toml` の `RATE_LIMITER`）。**無料プランで使える想定**で
> 作ってありますが、**プラン条件は変わりうる**ため、ここで
> 「有料プランが必要」と言われる可能性があります。
>
> **その場合はそこで止めて、メッセージをそのまま教えてください。**
> Workers Paid は月$5程度ですが、支払う前に代替案を検討します。

## C-5. 🔴 シークレットを設定する（4つ）

**1つずつ実行し、聞かれたら値を貼り付けて Enter** します。
**画面には表示されません**（伏せ字にもなりません、何も出ません）。正常です。

```bash
npx wrangler secret put ANTHROPIC_API_KEY
```
→ 手順 A-4 のキーを貼り付け

```bash
npx wrangler secret put FIREBASE_PROJECT_ID
```
→ `wanote-7dca0`

```bash
npx wrangler secret put FIREBASE_CLIENT_EMAIL
```
→ 手順 B-2 の `client_email`

```bash
npx wrangler secret put FIREBASE_PRIVATE_KEY
```
→ 手順 B-2 の `private_key`（**`\n` はそのまま、1行で**）

> **`REVENUECAT_SECRET_KEY` は今は設定しません。** RevenueCat は
> ストア申請待ちのため。**未設定でもアプリは動きます。**

> 🔴 **`FIREBASE_AUTH_EMULATOR_HOST` と `FIRESTORE_EMULATOR_HOST` は
> 絶対に設定しないでください。** 前者はトークンの署名検証を飛ばします。
> （`demo-` プロジェクトでのみ有効になるガードは入れてありますが、
> そもそも設定しないのが正しいです）

確認:

```bash
npx wrangler secret list
```

**4つ並んでいればOK**（値は表示されません）。

## C-6. シークレット反映後にもう一度デプロイ

```bash
npx wrangler deploy
```

### ✅ Cの完了条件

- [ ] `npx wrangler secret list` に4つ並んでいる
- [ ] デプロイが成功した
- [ ] **Worker のURLを控えた**

---

# 終わったら教えてください

**必要なのはこれだけです:**

1. **Worker のURL**（`https://wanote-functions.xxxxx.workers.dev`）
2. 途中で止まった箇所があれば、その画面のメッセージ

**キーもJSONも渡していただく必要はありません。**

## 受け取ったら私がやること

1. Worker のURLを `config/prod.json` に設定
2. **AI機能（相談・レポート・OCR）の通し確認**
3. **アカウント削除が最後まで完了することの確認**
   （現在は Worker が無いため途中で失敗します）
4. 実機ビルド用の設定を整える

---

# 後回しにしてよいもの

以下は**今回やらなくて構いません**。DNSの反映待ちがあるため、
別の日にまとめてやる方が効率的です。

- `wanote.jp` の DNS を Cloudflare に移管
- `support@wanote.jp` のメール受信（Email Routing）
- SPF / DMARC
- `api.wanote.jp` のカスタムドメイン
- プライバシーポリシーの公開（Pages）

> ただし **`api.wanote.jp` は出荷前に必ず設定してください。**
> バックエンドURLは**ビルド時にアプリへ埋め込まれる**ので、
> **出荷後は変更できません。** `*.workers.dev` を直接埋めたまま出すと、
> Cloudflare のアカウント名やWorker名を変えたくなった時点で詰みます。
> **テスト中は `*.workers.dev` のままで構いません。**
