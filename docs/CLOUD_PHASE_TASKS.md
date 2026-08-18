# クラウド設定フェーズでしかできない作業（漏れ防止リスト）

作成: 2026-08-11

**このファイルの役割**: ローカル環境では原理的に完了できず、実プロジェクト・
実アカウント・実機のいずれかを要する作業を1箇所に集める。個々の経緯は各コミット
と `SESSION_HANDOVER.md` にあるが、**着手時に見るのはこのリスト**でよい。

チェックは PM が実施したら埋める。

---

## A. Firebase（実プロジェクト）

- [ ] **A-1** Firebaseプロジェクトを作成し `flutterfire configure` を実行する
- [ ] **A-2** `lib/main.dart` の初期化を実プロジェクト対応にする。
      現在は**常に** `demoFirebaseOptions` を使う。`main.dart:15-33` のTODOに
      必要な形が書いてある（`useFirebaseEmulator ? demo : DefaultFirebaseOptions`）。
      **これをやらないと実プロジェクトに繋がらない**（起動時に失敗するので
      気づけるが、失敗すること自体は確実）
- [ ] **A-3** `firestore.rules` / `storage.rules` をデプロイする。
      ルール自体は本番用が書けており、ローカルのエミュレータも同じものを
      読んでいる（`firebase deploy --only firestore:rules,storage`）
- [ ] **A-4** Googleサインイン / Appleサインインの実設定（OAuthクライアント、
      Apple Developer の Sign in with Apple 構成）
- [ ] **A-5** 実アカウントでサインイン〜サインアウトを確認。
      **SDK更新でAPIが変わっている箇所なので、実機テストで最初に見る**

## B. Cloudflare Workers

- [ ] **B-1** `wrangler secret put` で以下を設定
      **注意: `REVENUECAT_SECRET_KEY` が未設定だと、アカウント削除時に
      RevenueCat のレコードが黙って残る**（ログには警告が出る）
      - `ANTHROPIC_API_KEY`
      - `REVENUECAT_SECRET_KEY`
      - `FIREBASE_PROJECT_ID`（実プロジェクトID）
      - `FIREBASE_CLIENT_EMAIL`（サービスアカウント）
      - `FIREBASE_PRIVATE_KEY`（同上・改行は `\n` エスケープで1行）
- [ ] **B-2** `FIREBASE_AUTH_EMULATOR_HOST` と `FIRESTORE_EMULATOR_HOST` を
      **絶対に設定しないこと**。前者は署名検証を飛ばすため
      （`demo-` プロジェクトでのみ有効になるガードは入れてあるが、
      そもそも設定しないのが正しい）
- [ ] **B-3** 初回デプロイで Durable Object のマイグレーションが適用されることを
      確認する（`wrangler.toml` の `[[migrations]] tag = "v1"`）。
      **適用済みのタグは番号を振り直さない**
- [ ] **B-4** サービスアカウントには Firestore への最小権限のみ付与する

## C. RevenueCat

- [ ] **C-1** ダッシュボードでエンタイトルメント **`premium`** を作成し、
      `premium_monthly` と `premium_yearly` の両方を紐づける。
      **識別子が異なる場合は `EntitlementIds.premium` を変更する**
- [ ] **C-2** 商品4種を登録（`premium_monthly` / `premium_yearly` /
      `ai_tickets_5` / `ai_tickets_15`）。**価格は仕様書8.2に記載がない**ため
      PM が決定する必要がある
- [ ] **C-3** 手数料体系を最新条件で確認する（仕様書8.2の注記）
- [ ] **C-4** **契約中にプロモーション権利を付与したときの実挙動を確認する。**
      実装は「契約中は付与せず保留に回す」設計なのでこの挙動に依存しないが、
      前提が正しいかは実キーでしか確認できない
- [ ] **C-5** `GET /subscribers/{uid}` のレスポンス形状を実物で確認する
      （`hasActiveEntitlement()` が `entitlements[id].expires_date` を見ている）
- [ ] **C-6** 実ストアでの購入・復元を確認する

## D. AdMob / 広告（→ `PLAN_ads.md`）

- [ ] **D-1** AdMob アカウントでアプリと広告ユニットを作成し、
      **本番の広告ユニットID**を `AdUnitIds` に設定する
      （iOS / Android × インタースティシャル）。
      現在は Google の**テストID**。**推測で本番IDを書かないこと**
- [ ] **D-2** `Info.plist` に **`SKAdNetworkItems`** を追加する。
      Google が公開している実IDのリストを転記する（数十件）。
      **推測で書かないこと**
- [ ] **D-3** ATT ダイアログの実挙動を実機で確認する
      （実装は 2026-08-18 に完了。それまで**この行が「確認する」と書かれていたため
      実装済みに見えており、コードが無いことに1週間気づけなかった**。
      未実装のものは「実装する」と書くこと）
- [ ] **D-4** 広告の実表示を実機で確認する（エミュレータ／Webでは不可）

## E. iOS 固有（Mac / Xcode が必要 → Codemagic で代替）

**2026-08-11 決定: Mac は用意せず Codemagic を使う。**
`flutter build ipa` は Xcode を要するため Windows では実行できない。
署名は App Store Connect の API キーを渡して Codemagic に管理させる。

- [ ] **E-0** Codemagic のアカウント作成とリポジトリ接続
- [ ] **E-0b** `codemagic.yaml` の作成（**Apple Developer Program 取得後**。
      それまでは署名なしの `flutter analyze` / `flutter test` だけ回す構成にできる）

- [ ] **E-1** `Info.plist` の権限説明文を**多言語化**する。
      `ja.lproj` / `en.lproj` に `InfoPlist.strings` を置き、
      **Xcodeプロジェクトに登録する**必要がある。
      `project.pbxproj` の手編集は壊すリスクが高く Windows では検証できない。
      当面は日本語のみで入る（説明文の追加自体は広告実装と同時に対応する）
- [ ] **E-2** 実機ビルドと App Store Connect の構成

## F. 実機でしか確認できない不具合・保留事項

- [ ] **F-1** **写真登録時のメモリ異常終了**（PM報告）。
      iOS Safari で発生。`image_picker` の生バイトを丸ごとメモリに読んでから
      圧縮しているため。**ネイティブでも同じ経路を通る**ので優先度が高い。
      対処は「読み込み時点で縮小（`image_picker` の `maxWidth`/`maxHeight` 指定）」が
      最小の変更
- [ ] **F-2** **画面遷移の残像**（PM報告）。iOS Safari で観測。
      ネイティブでは再現しない可能性が高い。再現したら
      `git show 8266922 47b5990` の実装を戻す。
      **戻すとAndroidのpredictive backとiOSのスワイプバックを失う**
- [ ] **F-3** アイコン・背景のピンチ調整の実操作確認
      （Webのファイル選択ダイアログを自動操作できず未検証）
- [ ] **F-4** Storage の孤児ファイル監査。Firestoreのドキュメントを消しても
      Storageのファイルは自動では消えない。実データが増えてから
      使用量と件数を突き合わせる
- [ ] **F-6** **リマインダーの実機確認**（2026-08-12 実装）。
      確認すること:
      - 通知権限のダイアログが「最初のリマインダー登録時」に出るか
      - 指定時刻に実際に鳴るか。**inexact アラームなので遅延の体感を見る**
        （遅すぎるなら exact への切り替えを再検討。判断材料は
        `ReminderNotificationAdapter` のコメント）
      - **端末を再起動しても予約が残るか**（`RECEIVE_BOOT_COMPLETED`）
      - 処方の終了日を過ぎたら鳴らなくなるか
- [ ] **F-7** **お知らせの実機確認**。コンソールで1件書いて、
      サインイン画面（`important: true`）とホームの両方に出ることを確認する
- [ ] **F-5** **アカウント削除の実機確認**（2026-08-12 実装）。
      ローカルでは Firestore/Storage のルールとサーバー側ルートまで
      検証済みだが、**実際に消えたことを確認できるのは実プロジェクトのみ**。
      確認すること:
      - Storage コンソールで `users/{uid}/` が空になっているか
      - Firestore で `users/{uid}` 配下が残っていないか
      - Google / Apple アカウントの再認証が実機で通るか
        （`signInWithGoogle` を再認証に使っている）
      - 削除後に**同じメールアドレスで新規登録できる**か

## I. 未配線のまま残っている機能（ローカルで対応可）

**クラウドフェーズを待つ必要はない。**「実装済み」と誤解しやすいので記録する。

- [x] **I-1** ~~投薬・予防のリマインダー通知が未配線~~ → **配線済み**（2026-08-12、`0703be9`）。
      **服薬リマインダー（仕様5.2）は計算部分ごと新規実装。**
      実機確認は F-6 へ。旧記述:
      `lib/features/medical/domain/reminder_scheduler.dart` と
      `lib/features/medical/notifications/reminder_notification_adapter.dart`
      は書かれているが、**どこからも呼ばれていない**
      （`grep -rn "ReminderScheduler\|ReminderNotificationAdapter" lib/` が
      定義元以外に何も出ない）。広告と同じ状態。
      **薬の飲み忘れ防止は本アプリの主要な価値の1つ**なので優先度は高い。
      配線には通知権限の要求（iOS/Android）と Info.plist / AndroidManifest の
      対応も要る
- [ ] **I-2** **広告が未配線**（`PLAN_ads.md`・PM承認済み・着手指示待ち）
- [x] **I-3** ~~お知らせ機能は存在しない~~ → **実装済み**（2026-08-12、`5bd986d`）。
      **Firebase コンソールで `announcements/{id}` を1件書けば出る。**
      アプリ側は読むだけ。運用手順は `CLOUD_ACCOUNT_SETUP.md` を参照

## H. 個人名義配信に伴う日程上の制約（2026-08-12 決定）

- [ ] **H-1** **Play のクローズドテスト（12人 / 14日間）**。
      個人アカウントの新規アプリに必須。**14日は短縮できない**ので、
      9/30 締切なら **9月中旬までに開始**し、**テスター12人を確保**する。
      これが間に合わないと Play に公開できない。
      **Apple 側にはこの要件は無い**
- [ ] **H-2** **将来の法人移管に備える**。Apple の App Transfer と Play の
      アプリ移行はどちらも可能だが手続きが要る。RevenueCat / AdMob /
      Firebase も移管または作り直し、プライバシーポリシーの事業者名も
      書き換えになる。**リリース前に法人化するなら、その方が安い**

## G. 運用開始後にデータを見て判断すること

- [ ] **G-1** 広告の頻度制限。現在は「1アクション1回」で時間/日次の上限なし。
      1日に何度も記録する利用者には毎回出る（`PLAN_ads.md` にリスクとして記録）
- [ ] **G-2** バナー広告の併用可否（コスト過多になった場合）
- [ ] **G-3** AIコストの実測と、無料版ユーザー数に対する比率の監視
      （仕様書9章）
- [ ] **G-4** 紹介特典の悪用状況。自己紹介の防止は同一uid判定のみで、
      捨てアドの別アカウントは防げない。上限5回が実質的な被害上限

---

## 参考：ローカルで完了済み・持ち越さないもの

混同しやすいので明記する。以下は**すでに終わっている**。

- Firestore / Storage の本番用ルールとそのテスト（72件）
- アカウント削除機能（App Store 5.1.1(v) 要件）
- 課金経路のサーバ側認可（誰でもプレミアム付与できる問題）
- 紹介者特典・保留付与
- セッション有効期限（1日・生体認証で通過）
- セキュリティ診断の指摘 全6件
- 画像サイズ上限 5MB の統一
