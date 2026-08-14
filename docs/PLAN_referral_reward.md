# 実装プラン：紹介者特典 ＋ 保留付与 ＋ セッション有効期限

**状態: 実装完了（2026-08-11）**

- パートC（セッション有効期限）: `20d28fd`
- パートA+B（紹介者特典・保留付与）: 下記コミット

実装時に変わった点:
- 保留分のパスを `users/{uid}/rewards/pending/{id}` から
  **`users/{uid}/pending_grants/{id}`** に変更。前者はセグメント数が合わず
  Firestore のドキュメントパスとして成立しないため
- `firestore.rules` は「変更なし」の想定だったが、`rewards/` と
  `pending_grants/` に**所有者読み取り専用**のルールを追加した
  （デフォルト拒否なのでUI表示ができなかった）
作成: 2026-08-11

前提となる `972de40`（課金経路のサーバ側認可）が入っていること。この土台
——Worker が Firestore に管理者権限で到達でき、引き換えが1トランザクションで
完結する——が無いと、以下はどれも安全に作れない。

---

## 決定事項（PM回答済み）

| # | 論点 | 決定 |
|---|---|---|
| 1 | 紹介者特典の上限5回をどこに持たせるか | **ユーザ単位**のカウンタ（将来コードが複数になっても通算5回） |
| 2 | 上限到達後のコードの扱い | **コード自体を無効化**（不正リスク軽減） |
| 3 | 紹介者へのRevenueCat付与が失敗したとき | **エラーログ出力＋pending記録**、運営が後日補填 |
| 4 | 契約者への特典 | **保留付与方式**（ストア側オファーは不要） |
| 5 | 保留分の積み上げ | **積み上げる**（解約時にまとめて適用） |
| 6 | 保留分の期限 | **発行から1年** |
| 7 | 適用トリガーの検証 | **Worker が RevenueCat に問い合わせて確認**（クライアントの申告は信じない） |
| 8 | セッションを無期限にしない | **前回ログインから1日経過で自動ログアウト** |

---

## パートC：セッション有効期限（1日）

### 現状

期限は**一切ない**。Firebase の永続セッションはリフレッシュトークンで無期限に
更新され、`AuthGateResolver` は生体認証の有無しか見ていない。一度ログインすれば
アプリを削除するかサインアウトするまでログイン状態が続く。

これは保留付与の前提ではない（契約確認は「アプリを開く」だけで走る）が、
医療情報を扱う以上、置きっぱなしのセッションを無期限に生かすのは避けたい。
先日のセキュリティ診断が「多重ログイン対策は実質UX機能」と評価した背景でもある。

### 設計

- 明示的なサインイン成功時に `auth.last_sign_in_at.{uid}` を
  SharedPreferences に記録する（セッション復帰では更新しない。
  そうしないと「開くたびに延命」されて期限が意味を失う）
- 判定は純粋関数に切り出し、`AuthGateResolver` の入力を1つ増やす:
  `sessionAgeExceeded` が true なら `requireSignIn`
- **起動時とレジューム時の両方**で判定する。数日バックグラウンドに置かれた
  ケースを起動時チェックだけでは拾えない
- 期限切れ時は `signOut()` を実行してからサインイン画面へ。
  「なぜ切れたか」を伝える文言をARBに追加する

### 判断が要る点

- **生体認証との関係**: 生体認証を有効にしている人も1日でパスワード再入力に
  なるか、生体認証で通過させるか。前者が安全、後者はUX重視。
  **PM判断待ち**（本プランは前者＝完全ログアウトで記述）
- **サーバ側の失効は行わない**: Firebase のリフレッシュトークン自体は生き続ける
  （ローカルのサインアウトのみ）。真に失効させるには Admin SDK の
  `revokeRefreshTokens` が要り、全端末が巻き込まれる。
  「端末に残ったセッションの露出時間を縮める」目的には
  ローカルサインアウトで足りると判断した

### 変更ファイル（パートC）

| ファイル | 内容 |
|---|---|
| `lib/features/auth/domain/session_expiry_policy.dart` | **新規** 経過時間から失効を判定する純粋関数 |
| `lib/features/auth/domain/auth_gate_resolver.dart` | `sessionAgeExceeded` を入力に追加 |
| `lib/features/auth/presentation/auth_controller.dart` | サインイン時刻の記録、起動・レジューム時の判定 |
| `lib/features/auth/presentation/screens/launch_gate_screen.dart` | レジューム監視（`WidgetsBindingObserver`） |
| ARB | 「一定時間が経過したため再度サインインしてください」 |

### テスト（パートC）

- 23時間経過では失効しない／25時間経過で失効する（境界）
- セッション復帰では記録時刻が更新されない（延命しないこと）
- 生体認証が有効でも期限切れならサインインを要求する
- レジューム時にも判定が走る

---

## データ設計

```
users/{uid}/rewards/referral
  rewardedCount: int        // 紹介者として受け取った回数（上限5）
  updatedAt: timestamp

users/{uid}/rewards/pending/{grantId}
  reason: 'referral' | 'redemption'
  months: 1
  createdAt: timestamp
  expiresAt: timestamp      // createdAt + 1年
  appliedAt: timestamp?     // 適用済みなら埋まる
  failureCount: int         // RevenueCat付与に失敗した回数（運営の補填対象）
```

いずれも `users/{uid}` 配下なので **firestore.rules は変更不要**。クライアントは
読めるが書けない（書くのは Worker のみ）。読めることで「紹介 n/5」「保留 n件」の
表示ができる。

---

## パートA/B：処理フロー

### A. コード引き換え時（既存ルートに追記）

`functions/src/routes/grantPromotionalEntitlement.ts`

1. 既存の検証（コード存在・有効・自己紹介でない・未引き換え・上限内）
2. **同一トランザクション**で以下を追加:
   - 被紹介者の引き換え記録（既存）
   - `referrerUid` があれば紹介者の `rewardedCount` を読み、5未満なら +1
   - 加算後に5に達したら `campaign_codes/{code}.active = false`
3. コミット後、**被紹介者 → 紹介者** の順に付与（下記Bの判定を通す）

紹介者側が失敗しても被紹介者のレスポンスは成功のまま返す。失敗は
`console.error` と `failureCount` に記録する。

### B. 付与の実処理（新規 `lib/grantOrDefer.ts`）

対象 uid について:

1. RevenueCat `GET /subscribers/{uid}` で `premium` の有効性を確認
2. **無効** → Promotional Entitlement を即時付与
3. **有効** → `users/{uid}/rewards/pending/{grantId}` に記録して終了

この分岐が保留付与の本体。契約中に付与しても重なって消えるため、
記録に切り替える。

### C. 保留分の適用（新規ルート `POST /billing/apply-pending-grants`）

1. ID トークンで uid を確定
2. **RevenueCat に問い合わせて premium が無効であることを確認**
   （有効なら何もせず 200 を返す。クライアントの申告は信じない）
3. `pending` を走査し、`appliedAt == null` かつ `expiresAt > now` のものを
   古い順に適用。適用ごとに `appliedAt` を埋める
4. 期限切れは `appliedAt` を埋めずスキップし、期限切れとしてログ

**クライアント側の呼び出し箇所**: `BillingRepository.premiumStatusChanges()` が
premium=false を流したとき、および起動時。既存のストリームがあるので Cron は不要。

**制約**: 解約後にアプリを開かない人には適用されない。使わない人に premium を
付けても意味がないため許容する。

---

## 変更ファイル

| ファイル | 内容 |
|---|---|
| `functions/src/lib/grantOrDefer.ts` | **新規** 契約確認 → 即時付与 or 保留記録 |
| `functions/src/lib/revenueCatClient.ts` | `getSubscriber()` を追加（契約状況の取得） |
| `functions/src/routes/grantPromotionalEntitlement.ts` | 紹介者カウンタ・無効化・2人目の付与 |
| `functions/src/routes/applyPendingGrants.ts` | **新規** 保留分の適用 |
| `functions/src/routes/referralCode.ts` | `maxRedemptions` を 1000 → 5 |
| `functions/src/index.ts` | ルート登録 |
| `lib/features/billing/data/billing_backend_client.dart` | `applyPendingGrants()` を追加 |
| `lib/features/billing/data/billing_repository.dart` | premium=false で上記を呼ぶ |
| ARB | 「ご契約中のため契約終了後に適用されます」等の文言 |
| `firestore.rules` | **変更なし** |

---

## テスト方針

Worker（vitest）:
- 上限5回に達したらコードが無効化される／6人目が `inactive` で弾かれる
- 紹介者への付与が失敗しても被紹介者は成功を受け取る
- 契約中は即時付与されず pending に積まれる
- **契約中に `apply-pending-grants` を叩いても付与されない**（申告偽装の防止）
- 期限切れの保留分は適用されない
- 保留が複数あるとき古い順に適用される

ルールテスト:
- クライアントから `rewards/` を書けない
- 他人の `rewards/` を読めない

---

## 未解決・要注意

- **RevenueCat の実挙動は未検証**（実キーが無いため）。特に「契約中に
  Promotional Entitlement を付与したときの重なり方」は実キー設定後に必ず確認する。
  本プランはその挙動に依存しない設計（契約中は付与しない）にしてあるが、
  `getSubscriber()` のレスポンス形状は実物で確認が要る
- 「契約中の人にも即時に価値を届けたい」となった場合は、Apple のプロモーション
  オファー / Google Play の繰延請求が必要。**本プランの範囲外**、独立タスク
- 自己紹介の防止は同一 uid 判定のみ。捨てアドで別アカウントを作れば回避可能。
  上限5回が実質的な被害上限になっている
