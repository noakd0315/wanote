# wanote 作業引き継ぎメモ

最終更新: 2026-08-14（**Firebase の実環境構築まで完了**。次は Android 実機テスト、
または Cloudflare / Anthropic の設定から。Flutter 320 / Worker 119 / rules 77）

**着手順は `docs/PLAN_implementation_first.md` が正**（申請より実装優先・PM指示）。
実環境の残作業は `docs/CLOUD_SETUP_CHECKLIST.md`。

再開時はこのファイルを読んでから作業を始めてください。

---

## 再開時の指示（コピペ用）

```
C:\Dev\wanote\docs\SESSION_HANDOVER.md を読んで、続きから作業を再開してください。
```

---

## 0-A. 2026-08-06 夜にやったこと

1. **アイコン写真のピンチ調整**（`611bbc0`）— PM依頼「LINEやFacebookのように
   選択後、設定イメージの中でピンチアウトで調整できるようにしたい」
   - 新規 `lib/features/auth/presentation/screens/icon_crop_screen.dart`
   - 写真選択直後にこの画面をpush。円の外を暗くし、ピンチで拡大・ドラッグで位置調整
   - **調整バー3本（左右／上下／ズーム）は削除**（PM選択「削除してピンチに一本化」）。
     未保存の写真は「位置・サイズを調整」ボタンで再調整できる
   - 保存形式は従来どおり `iconAlignmentX/Y` + `iconZoom` のまま。
     Firestoreやアバター表示側は無変更
   - プレビューは `PetIconAvatar` と**同じ組み方**（cover-fit + Transform.scale、
     どちらも同じ alignment）を再現している。InteractiveViewer の行列から
     alignment を逆算すると**正方形でない写真でズレる**ため。この2つは
     必ずセットで直すこと
   - ARBの `petProfileFormIconOffsetX/YLabel`・`petProfileFormIconZoomLabel` を削除し、
     `petProfileFormAdjustIconButton` / `iconCropTitle` / `iconCropConfirmButton` /
     `iconCropHint` を日英に追加
   - テスト5本追加（`test/features/auth/presentation/icon_crop_screen_test.dart`）
   - **未: ブラウザでの実操作確認**。web版のファイル選択ダイアログを自動操作できず、
     写真を選ぶところから先に進めていない。要手動確認

2. **Webでエミュレータに繋がらない不具合を修正**（`2b1f44f`）
   - 症状: ローカルWebでサインインすると「問題が発生しました」。実際は本物の
     `identitytoolkit.googleapis.com` に飛んでいて "API key not valid"
   - 原因: web では `Firebase.initializeApp()` の中で firebase_auth_web の
     `ensurePluginInitialized` が auth の初期化を完了させてしまう。その後に
     `useAuthEmulator()` を呼んでも JS SDK が `auth/emulator-config-failed` を投げ、
     **firebase_auth_web がそれを握りつぶす**ので成功したように見えて何もしていない
   - 対処: プラグインがリロード時に使っているのと同じ経路（sessionStorage）に、
     `initializeApp()` の**前**にエミュレータのoriginを書いておく。web限定・
     `USE_FIREBASE_EMULATOR` 配下。他プラットフォームはno-opスタブ
   - sessionStorageを空にした状態から検証済み。エミュレータでサインイン成功
   - **注意**: プラグイン側が `hostname == 'localhost'` でしか読まないので、
     `--web-hostname 127.0.0.1` では効かない。`localhost` で起動すること

### 動作確認の手順メモ（次回はここから）

```
flutter run -d web-server --web-port 5001 --web-hostname localhost   --dart-define=USE_FIREBASE_EMULATOR=true   --dart-define=AI_BACKEND_BASE_URL=http://localhost:8787
```

ブラウザ自動操作のコツ（今回ハマった点）:
- **タブを新規に作ってから** `navigate` すること。使い回したタブだと
  `flt-semantics` ツリーが構築されず、座標クリックも効かない状態になった
- セマンティクス有効化 → `flt-semantics-placeholder` を `.click()`
- ボタン押下 → `flt-semantics[role=button]` を `.click()`（座標クリックは不安定）
- テキスト入力 → 対象 `<input>` を `focus()` してから
  `document.execCommand('insertText', false, '...')`。
  **パスワード欄は `input.type='text'` に変えてから**でないと insertText が効かない

## 0-A2. 2026-08-10 にやったこと

1. **背景写真のピンチ調整**（`377e546`）
   - `IconCropScreen` を `PhotoCropScreen` に一般化。枠のアスペクト比と
     円形マスクの有無をパラメータにして、アイコンと背景で**同じジェスチャ実装**を使う
   - 背景は**端末のアスペクト比**で切り抜くので、プレビューがホーム画面の見え方と一致する
   - `PetProfile` に `backgroundAlignmentX/Y`・`backgroundZoom` を追加。
     アイコンとは**別フィールド**（切り抜く形が違うため共用できない）。
     既存ドキュメントは未設定として読める
   - ホーム背景の描画を `PetBackgroundPhoto` に集約。
     **`PetIconAvatar` / `PhotoCropScreen` のプレビューと同じ組み方**。
     どれか1つを変えたら3つとも直すこと
   - **ついでに直した不具合**: 新規ペット作成時にフレーミングが保存されていなかった
     （`createPet()` にフレーミング引数が無く、編集分岐でしか適用していなかった）

2. **前回見つかった課題の解消**（`5320b96`）
   - 未マップの認証エラーコードを**デバッグビルドでのみ**画面に併記。
     全部「問題が発生しました」だったのが前回の誤診の直接原因。
     wrong-password/user-not-found の意図的な同一文言はそのまま
   - `_claimSession()` を**リモート先行**に変更。異常終了しても
     「旧端末が残る」ではなく「入り直し」で済む。テストで順序を固定
   - `AI_BACKEND_BASE_URL` 未指定時、**ページの配信ホストに追従**。
     スマホからAI/OCR/課金がスマホ自身のlocalhostに飛んでいた
   - `Purchases.purchasePackage` → `Purchases.purchase(PurchaseParams.package(...))`

3. **画面遷移の即時化とグラフまわり**（`8266922`）
   - ページ遷移のアニメーション除去は**実装したのち差し戻した**。
     残像は iOS Safari で観測されたもので、ネイティブでは再現しない可能性が高く、
     対処するとAndroidのpredictive backとiOSのスワイプバックを失うため。
     **詳細と再開手順は 2.6 を参照**
   - トイレの頻度グラフを**同じ画面内で切り替え**に変更。
     別画面をpushするとAppBarがアクションなしのものに差し替わり、
     戻る手段のボタンが消えていた
   - 体重グラフの期間を **3ヶ月／6ヶ月／1年**に変更（1ヶ月を廃止）

4. **`flutter analyze` を 0 件にした**（`prefer_initializing_formals` ×7）。
   `AuthController` のコンストラクタを private な initializing formal に変更。
   呼び出し側は従来どおり `authRepository:` などの公開名のままでよい

### まだ確認できていないこと

- ~~アイコン・背景のピンチ調整の実機確認~~ → **PM確認済み・問題なし**（8/10）
- 写真登録時のメモリ異常終了は、PM判断により**クラウド環境に載せてから確認**
- 画面遷移の残像は、PM判断により**実機で確認してから対処を判断**（2.6 参照）
- **スクリーンショット40枚のうち3画面が古い**。取得後に
  「証明書一覧」「注意書きの赤字化」「アイコン/背景の調整画面」が変わっている。
  デザイン修正が一段落してからまとめて撮り直すのが効率的

---

## 0-A3. 2026-08-10 深夜：セキュリティルールと診断

### やったこと

1. **Firestore / Storage の本番ルール作成**（`5d03bdf`）
   - `allow read, write: if true` を置き換え。全データが `users/{uid}` 配下なので
     パス中のuidが所有者そのものになる
   - **サブコレクションは `{document=**}` でまとめず個別に列挙**。
     ルールの許可はOR結合なので、包括マッチを置くと
     `redeemed_codes` の削除禁止が無効化されるため
   - Storageは10MB上限＋`image/*` 限定。deleteは分けて記述
     （deleteでは `request.resource` がnullになるため）
   - **エミュレータも本番と同じルールで動く**（firebase.jsonが同じファイルを指す）

2. **ルールテスト** `security-rules-test/`（**66件**）
   - Firestore 52件 + Storage 14件。エミュレータに対して実行
   - **アプリとは別のproject ID**（`demo-wanote-rules-test`）を使う。
     `clearFirestore()` は指定projectを消すので、同じにすると
     **開発データが毎回消える**（実際に一度消してエクスポートから復旧した）
   - 実行: `cd security-rules-test && npx vitest run`（要 `docker compose up -d`）

3. **別エージェントによるセキュリティ診断を実施**（結果は下記）

### 診断で見つかり、その場で直したもの

- **【自分で入れた不具合】`allow create: if false` が紹介コード機能を破壊していた。**
  `getOrCreateReferralCode` はクライアントから `campaign_codes/REF-XXXX` を
  作成するため、初回表示が必ず PERMISSION_DENIED になっていた。
  しかも**テストがその破壊を「正しい」と固定していた**。
  → 自分の紹介コードだけ、id・全フィールドを固定した上で作成可に変更
- **`allow read` は `list` も含む** → 誰でも `campaign_codes` を全件ダンプでき、
  全ユーザのuid前8桁が漏れる状態だった。`allow get` / `allow list: if false` に分離
- Storageルールのテストが0件だった → 14件追加。**証明書の写真**という
  最も機微なデータを守っている部分なので優先した

### ~~【要対応】診断で見つかった未修正の問題~~ → **全件対応済み（8/11）**

対応コミット: `972de40`（問題1・2）、`d42c09a`（問題3〜6）。
以下は当時の記録として残す。


**1. 最優先 — 誰でも自分にプレミアムを付与できる**
`functions/src/routes/grantPromotionalEntitlement.ts`
IDトークンを検証するだけで、**コードを引き換えたかを一切確認していない**。
無料アカウントを作ってトークンを取り出し、bodyなしでPOSTするだけで
プレミアムが付く（1日5回・無期限）。Firestoreの引き換え記録もキャンペーン上限も
経由しない。現在はRevenueCatキーが未設定でモックが返るため顕在化していないだけ。
**根本原因**: Workerが Firestore を見られない設計なので、
状態を要する判定が全部クライアントに寄っている。
**対処**: Workerにサービスアカウントを持たせ、コード検証・上限・引き換え記録を
Worker内のトランザクションで完結させる。これは設計変更なので未着手

**2. 利用カウンタがクライアント書き込み可能** — 自分で `unlimited: true` を
書けばAI無制限。ルールでは塞げない（自分のドキュメントなので）。
Worker側のレート制限は効くので請求は青天井にはならないが、
プラン制限としては機能しない。**1と同じ対処で解決する**

**3. エミュレータ用トークン検証のバイパス** `verifyFirebaseToken.ts:31`
`FIREBASE_AUTH_EMULATOR_HOST` が存在すると**署名検証を丸ごと飛ばす**。
本番デプロイに紛れ込むと任意ユーザーになりすませる。
現状 `.dev.vars` にしかなく `wrangler deploy` は読まないので安全だが、
`FIREBASE_PROJECT_ID` が `demo-` で始まる場合のみ有効、という条件を足すべき

**4. レート制限が非アトミック** `rateLimiter.ts` — get→比較→put で
CASなし。かつCloudflare KVは結果整合。同時リクエストで上限を大きく超えられる。
**これが唯一のサーバ側コスト上限**なので、Durable Object等に置き換えたい

**5. OCRの画像サイズ無制限** `ocr.ts:56` — 長さ0でないことしか見ていない。
最大100MBのbase64を10回/日送れる。7MB程度で413を返すべき

**6. OCRのエラー本文がそのまま返る** `ocr.ts:79` — Anthropicのレスポンス本文を
そのままクライアントに返している（APIキーは含まれないが内部情報が漏れる）。
他の3ルートは汎用メッセージなので揃えるべき

### 診断で「問題なし」と確認された領域

- **医療データのクロスユーザーアクセスは塞がっている**（診断の主目的）。
  Firestore・Storageとも、他人のペットの記録・写真・証明書には到達できない
- **コミットされたシークレットなし**。`firebase_options_demo.dart` のキーは
  意図的なダミー（Firebase JS SDKが形式を検証するため形だけ本物風）
- **AnthropicキーもRevenueCatキーもクライアントに到達しない**
- **エミュレータ用のfetch書き換えは本番ビルドで有効化できない**
  （`bool.fromEnvironment` のコンパイル時定数のみ、実行時の有効化経路なし）
- ログ・SharedPreferencesに個人情報なし。パスワードは保存していない
- Anthropicに送るデータは必要最小限（uid・ペット名・メールを送っていない）

### 総括（診断エージェントの結論）

**実ユーザーを乗せるにはまだ不可。ただし問題は医療データではなく課金経路に集中している。**
CLAUDE.mdが求めるアクセス制御自体は正しく実装できている。
上記1（＋2）を直すことが実ユーザー投入の前提条件。

---

## 0-A4. 2026-08-10 深夜：UI修正（`0338385`）

- **文言**（`5d03bdf`に同梱）: フッター「日常記録→日々の記録」「設定・課金→設定」
  （設定はEN "Settings" も）、日々の記録のタブ「健康記録→健康」、
  各画面タイトル「健康の記録／体重の記録／トイレの記録」、
  医療タブ「予防医療→予防」、予防画面タイトル「予防医療」
- **ホームのショートカット再デザイン**: 等幅Expanded＋IntrinsicHeightで
  **日英それぞれ5つ（現在4つ）が同一サイズ**。背景写真に依存しないよう
  半透明の黒をやめ、テーマのサーフェス色＋影のカードにした。テストで固定
- **ショートカット遷移がセクション＋内側タブの切替に変更**。
  以前は画面を直接pushしていたためタブ帯が出ず、フッター経由と見た目が違った。
  切替はHomeShellしかできないので判断をそちらに寄せ、
  各セクションの既存TabControllerをValueNotifierで駆動している
  （IndexedStack内で状態を保持するため作り直せない）
- **AI相談のショートカットを削除**（フッターと重複）。
  これに伴いHomeScreenのconsultation関連の配線も除去
- **フッターのアイコンずれ**: EN "AI consultation" が2行に折り返し、
  そのアイコンだけ上にずれていた。`NavigationDestination` はラベルを
  maxLines無しの `Text` で描き、アイコンをそれ基準に配置するため。
  ウィジェット側に制御手段がないので**文字列を短くする**しかない → "AI chat"
- **`web/index.html` に viewport メタタグが無かった**（新発見）。
  スマホのブラウザが約980px幅でレイアウトして縮小表示するため、
  **アプリ全体が小さく表示される**状態だった。標準のタグを追加。
  360px幅で `innerWidth` が 980→360 になることを確認済み

### 注意（テストで検証できないこと）

**`flutter test` は固定幅のテストフォントに差し替わる**ため、
文字幅に依存するレイアウト（フッターの折り返し等）は**ウィジェットテストで
検証できない**。全グリフが1em幅になるので "Medical" ですら折り返す判定になる。
一度そのテストを書いたが、実フォントと乖離するため削除した。
**この種の確認はブラウザの実描画で行うこと。**

なお、EN 360px でのフッター見た目そのものは**目視確認できていない**
（ブラウザペインのcanvas再描画の問題でスクリーンショットが崩れる。
DOM計測上はレイアウト正常）。実機で確認してほしい。

---

## 0-A5. 2026-08-11：課金のサーバ側認可・セッション期限・セキュリティ指摘の解消

| 内容 | コミット |
|---|---|
| 課金経路のサーバ側認可（誰でもプレミアム付与できる問題） | `972de40` |
| セッション有効期限 1日（生体認証で通過） | `20d28fd` |
| 紹介者特典（上限5・ユーザ単位）＋保留付与 | `33f2ff7` |
| セキュリティ指摘の残り4件 | `d42c09a` |

**セキュリティ診断の指摘は全件クローズしました。** 詳細は 0-A3 の記録を参照。

### 特に注意して引き継ぐ点

- **Worker が Firestore に到達できるようになった**（`functions/src/lib/firestoreClient.ts`）。
  ローカルはエミュレータの `owner` 資格情報、本番はサービスアカウント。
  **本番用に `FIREBASE_CLIENT_EMAIL` と `FIREBASE_PRIVATE_KEY` の設定が必要**
  （`wrangler secret put`。`functions/.dev.vars.example` に手順あり）
- **レート制限が Durable Object になった**。`wrangler.toml` に
  `[[migrations]] tag = "v1"` を追加済み。**初回デプロイ時に必要**で、
  適用済みのタグは番号を振り直さないこと
- **`campaign_codes` と `redeemed_codes` はクライアントから完全に遮断**。
  読み書きとも Worker のみ。UI 表示用に `rewards/` と `pending_grants/` は
  所有者の**読み取りのみ**許可
- **エミュレータ用の認証バイパスは `demo-` プロジェクトでのみ有効**。
  実プロジェクトに `FIREBASE_AUTH_EMULATOR_HOST` が紛れ込んでも安全
- **既存ログイン中のユーザは一度だけ再認証を求められる**
  （認証時刻の記録が無いセッションは期限切れ扱いのため）

---

## 0-A6. 2026-08-12：プライバシーポリシー下書き・アカウント削除機能

### プライバシーポリシー

`docs/PRIVACY_POLICY_DRAFT.md` に日本語の下書きを作成。
**公開前に PM 本人の確認が必要**（法律の専門家ではないため）。
【事業者名】は 0-5（個人／法人）の判断待ち。英語版は未作成。

下書きを書くために実装を調べた結果わかったこと（ポリシーの根拠）:

- 解析SDK（Analytics / Crashlytics / Sentry）は**1つも入っていない**
  → ストアの「データ収集」申告で「収集しない」と答えられる
- AIレポートは `summarizeReportStats()` で**数値5項目に集約してから**送信。
  相談は質問文と記録の**表示名・タグのみ**。
  いずれも **uid・メールアドレス・ペット名は送っていない**
- 生体情報は `local_auth` で端末内完結。送信経路が存在しない

### アカウント削除機能（App Store 5.1.1(v) 要件）

**下書き作成中に「未実装」と判明したため、PM 指示で先に実装した。**
設定 →「アカウントを削除」。

**削除の順序が設計そのもの。並べ替えてはいけない。**

```
Storage の画像 → Firestore のドキュメント → サーバ側の課金レコード → Firebase Auth
```

`firestore.rules` / `storage.rules` / Worker の全ルートが
`request.auth.uid` で認可している。**認証情報を先に消すと、残ったデータに
二度と到達できなくなる**（利用者も、再試行も、運営も）。最後に消せば
どの段階で失敗しても**丸ごとやり直せる**。各ステップは冪等。

| 追加物 | 場所 |
|---|---|
| 順序を持つ本体 | `lib/features/auth/data/account_deletion_service.dart` |
| Firestore の走査 | `.../account_document_eraser.dart` |
| Storage の走査 | `.../account_file_eraser.dart` |
| Worker 呼び出し | `.../account_backend_client.dart` |
| 再認証と prefs 掃除 | `AuthController.deleteAccount()` |
| 画面 | `.../screens/account_deletion_screen.dart` |
| サーバ側 | `functions/src/routes/deleteAccountServerData.ts` |

**注意点**

- **`FirestorePaths.petSubcollectionNames` が漏れると、そのサブコレクションは
  削除されずに残る。** Firestore はドキュメントを消してもサブコレクションを
  消さない。**ペットにサブコレクションを追加したらこのリストにも追加すること**
- サーバ側でしか消せないもの（`rewards` / `pending_grants` /
  `redeemed_codes` / 自分の `campaign_codes`）は Worker の
  `POST /account/delete-server-data` が担当。**クライアントに開放してはいけない**
  （redeemed_codes を消せる = 同じコードを二度使える）
- 紹介コードは uid の**先頭8文字**から作るため衝突しうる。
  Worker は `referrerUid` を確認してから消している
- 削除前に再認証する（メールはパスワード、Google/Apple は再サインイン）
- **サブスクは自動解約されないことを画面に明示**。課金はストア保持のため

**検証済み**

- Flutter 260件 / Worker 108件 / ルール 72件 すべて green、`flutter analyze` 0件
- **実エミュレータ＋実 Worker で end-to-end 確認**：サーバ側4件が消え、
  他人の紹介コードは残り、再実行しても 200（冪等）

**未検証**: 実機・実プロジェクトでの動作（`CLOUD_PHASE_TASKS.md` F-5）

### 削除しきれていないもの（監査結果・PM に報告済み）

「すべて削除できたか」を確認するために全経路を調べた結果:

| 残るもの | 対応 |
|---|---|
| **RevenueCat の subscriber**（uid と購入履歴） | **修正済み**（`fdf5edf`） |
| **Anthropic に送信済みの内容** | **削除できない**。Anthropic の保持ポリシー次第。**ポリシーへの明記が必要** |
| **他人の `redeemed_codes/{REF-XXXX}`**（消えた人のコードが文書IDに残る） | **意図的に残す**。消すとその人が同じコードを再利用できてしまう |
| レート制限の Durable Object（uid がキー） | ウィンドウ経過（最長24h）で `alarm()` が自動削除。放置で可 |
| Apple / Google 側の購入記録 | ストアの管理下。当方からは削除不可 |

**FCM トークンも `flutter_secure_storage` も未使用**なので、その経路の
残留は無い（確認済み）。

### 紹介コードの衝突（修正済み `fdf5edf`）

`deriveReferralCode()` は uid の先頭8文字を**大文字化**する。
Firebase の uid は**大文字小文字を区別する**ので、`abcdefgh…` と
`ABCDEFGH…` は同じコードになる。旧実装は「既に存在する＝自分のもの」と
扱っていたため、**2人目の「自分の紹介コード」が実際には他人を紹介する
コードになっていた**。招待した友人の特典は赤の他人に付き、
自分のカウンタは一生増えない。**エラーは出ない。**

修正: `referrerUid` を**確認**し、他人のものなら次の候補
（`REF-XXXXXXXX-2` …）へ。候補が尽きたら **502 で失敗させる**
（他人のコードを返すくらいなら失敗させる）。

**Dart 側の `ReferralCodeGenerator` は削除した。** テスト以外から
使われておらず、サーバの新しい規則（`-2` 付き）を知らないため、
**放置すると同じバグが復活する二重の真実**になっていた。

---

## 0-A7. 2026-08-12：ポリシーの記述と実装の食い違い（PM指摘）

**PM 指摘**: 「アプリにお知らせ機能がない認識だが、ポリシーに
アプリによるお知らせが書かれている」→ **そのとおりだった。**

調べたところ**通知まわりは3か所とも実態と合っていなかった**。

| 記述 | 実態 |
|---|---|
| 「重要な変更はアプリ内でお知らせします」 | **お知らせ機能は無い**。作る予定も無い → 削除 |
| Firebase の目的に「通知」 | **FCM は未使用**。`firebase_messaging` は依存にあるが**コードから一切呼んでいない** → 削除 |
| 「リマインダー通知」 | **部品はあるが未配線** → 記述は残し、端末内で完結する旨を明記 |

### ここから得た教訓（次回も同じ確認をすること）

**ポリシーは公開時点で真でなければならない。** この草案は
「完成後のアプリ」を書いていて、**未配線の機能まで書いてしまっていた**。
`PRIVACY_POLICY_DRAFT.md` の **A2** に、公開前に実装と突き合わせる
チェックリストを作った（リマインダー・広告・ATT）。

**「実装したのにポリシーに無い」も同じくらい危ない。** 公開直前に
両方向で突き合わせること。

### 未配線のまま残っている機能（`CLOUD_PHASE_TASKS.md` I 節に追加）

- **I-1 リマインダー通知が未配線**。広告と同じ状態で、
  `ReminderScheduler` / `ReminderNotificationAdapter` を**誰も呼んでいない**。
  **薬の飲み忘れ防止は本アプリの主要な価値**なので優先度は高い
- **I-2 広告が未配線**（`PLAN_ads.md`・着手指示待ち）
- **I-3 お知らせ機能は無い**。ポリシー変更時の周知手段は別途要検討

---

## 0-A8. 2026-08-12：方針転換と、リマインダー／お知らせの実装

### 方針転換（PM指示）

> 申請以外のクラウド環境を先に整え、実装ベースで完成とテストを急ぎたい。
> 今は申請優先になり、大事な機能が実装されていないまま先に進んでいる。

**指摘は正しかった。** 調べた結果、**動いていない機能が3件**あった。
`PLAN_implementation_first.md` に改訂計画を作成。**着手順はそちらが正。**

**「申請待ち」の整理も間違っていた**。Firebase / Cloudflare / Anthropic /
AdMob は**すべて申請不要で即日**。**Android 実機での通しテストは
Firebase を作った当日からできる**（USB接続、Play Console 不要）。
申請が本当に要るのは **iOS 実機**と**課金（RevenueCat）**だけ。

申請は「家族と相談してから」と保留（2026-08-12）。

### 1-1 リマインダー配線（`0703be9`）

**服薬リマインダー（仕様5.2）は計算する仕組みごと存在しなかった。**
フォームは `reminder_enabled` / `reminder_time` を保存していたが、
それを読むコードが1行も無かった。予防医療側は計算部分はあったが未配線。

- `MedicationReminderScheduler` を**新規作成**。
  開始前・停止済み・**終了した処方**は鳴らさない
  （終わった薬を「飲んでください」と言うのは、鳴らないより悪い）
- **配線方式を変えた**。画面ごとに「保存したら組み直す」を呼ぶのではなく、
  `ReminderSyncService` が **Firestore のストリームを購読して自動で組み直す**。
  **6画面が呼び出しを覚えている設計こそが今回のバグの構造**だったため
- 通知許可は「**最初にリマインダーが実際に存在した瞬間**」に要求する

**判断が要る点2つ**:

1. **アラームを inexact にした。前任の判断（exact でないと日付がずれる）と逆。**
   `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` は Play がアラーム・カレンダー
   アプリに限定し、Android 14 では手動許可が要る。**拒否されると一切鳴らない**。
   数分遅れる方がましと判断した。**実機で体感を見て再判断すること**（F-6）
2. `flutter_timezone` を追加。無いと `tz.local` が UTC のままで、
   毎日8時のリマインダーが UTC の時計で回る（日本では偶然正しい）

`AndroidManifest.xml` に `POST_NOTIFICATIONS` と
`RECEIVE_BOOT_COMPLETED`、プラグインのレシーバを追加。
**後者が無いと端末再起動で予約が全部消える。**

### 1-4 お知らせ機能（`5bd986d`）

PM要望。**問い合わせに答えられない期間を伝える手段**が無かった。
ポリシー改定の周知手段も同時に解決する。

- **管理画面は作っていない。** Firebase コンソールで
  `announcements/{id}` を1件書けば出る。手順は `CLOUD_ACCOUNT_SETUP.md`
- **`expires_at` が要件の中心。** 期間が過ぎたら自動で消えないと、
  営業しているのに休業中と表示され続ける
- **未サインインでも読めるルールにした**（DB内で唯一の公開パス）。
  サインインできない障害こそ伝えたいため。`important: true` のものだけ
  サインイン画面に出す
- 既読は端末内。同期すると**書き込み経路を開けることになる**ので持たない

---

## 0-A9. 2026-08-14：Firebase 実環境の構築（完了）

**プロジェクト `wanote-7dca0`**（アカウント: wanote.app.reply@gmail.com）

| | |
|---|---|
| Authentication（メール/パスワード） | ✅ 実アカウントでサインアップ／サインイン確認済み |
| Firestore | ✅ `(default)` / STANDARD / **asia-northeast1** |
| Firestore ルール | ✅ デプロイ・**実データで動作確認済み** |
| Storage | ✅ `wanote-7dca0.firebasestorage.app` |
| Storage ルール | ✅ デプロイ・**実データで動作確認済み** |
| アプリ登録 | ✅ Android / iOS とも `jp.wanote.app` |
| `main.dart` の接続 | ✅ **実プロジェクトを向くよう修正**（`41f4344`。A-2 完了） |

### 実プロジェクトで確認した内容（エミュレータではなく本番）

- **他人のペット記録**: 読み・書きとも 403
- **他人の証明書画像**: 読み・上書き・削除とも 403
- **5MB超のアップロード**: 403（上限が効いている）
- 一般ユーザによる**お知らせの書き込み**: 403

テストアカウント・テストデータはすべて削除済み。

### つまずいた点（次回同じ轍を踏まないために）

1. **`flutterfire configure` は内部で `firebase` コマンドを呼ぶ。**
   `npx firebase-tools` では見つけられず**無言でハングする**。
   → `npm install -g firebase-tools` で解決
2. **`flutterfire` は PATH に入らない**（`Pub\Cachein` が既定で PATH 外）。
   → `dart pub global run flutterfire_cli:flutterfire ...` か .bat のフルパス
3. **iOS の `GoogleService-Info.plist` は flutterfire が置いてくれない**
   （Windows では Xcode プロジェクトへ登録できないため）。
   → `firebase apps:sdkconfig IOS <appId> --out ...` で別途取得済み。
   **Xcode プロジェクトへの登録は Codemagic フェーズ**
4. **コンソールの「ログイン方法」は保存ボタンを押さないと反映されない。**
   画面上は有効に見える。**実際に叩いて確認するまで信用しないこと**
5. `flutterfire configure` は **`firebase.json` を1行に潰す**。整形し直した

### 次にやること

**Android 実機テストは申請不要で今日から可能。** 現時点で動く範囲:

| 機能 | 実機で確認できるか |
|---|---|
| サインイン・記録・写真・グラフ | ✅ |
| リマインダー通知 | ✅ **未検証項目が集中しているので最優先** |
| 広告（テストID） | ✅ RevenueCat 無しでも出る（`37d4bc3`） |
| AI相談・レポート・OCR | ❌ Cloudflare + Anthropic 未設定 |
| 課金 | ❌ RevenueCat（申請待ち） |

---

## 0-D. 【次回の最優先】バンドルID変更ほか（PM承認済み・未着手）

**中断理由**: PCのバッテリー保全のためシャットダウン（2026-08-11 夜）。
クラウド設定は明日以降。**コードは未変更、リポジトリはクリーン。**

### 決定済みの前提

| 項目 | 決定 |
|---|---|
| ドメイン | **`wanote.jp` 取得済み**（サーバーは未契約） |
| バンドルID | **`jp.wanote.app`**（現在は `com.example.wanote`） |
| バックエンドURL | **`api.wanote.jp`** を挟む（`*.workers.dev` を直接埋めない） |
| LP・プライバシーポリシー | Cloudflare Pages で `wanote.jp` に置く |

### 次回やること（この順で）

**1. バンドルIDの一括変更** — 追跡対象の7ファイル

```
android/app/build.gradle.kts            applicationId / namespace
android/app/src/main/kotlin/com/example/wanote/MainActivity.kt
                                        package 宣言 + ディレクトリ移動
                                        → jp/wanote/app/MainActivity.kt
ios/Runner.xcodeproj/project.pbxproj    PRODUCT_BUNDLE_IDENTIFIER
                                        （RunnerTests ターゲットも）
macos/Runner.xcodeproj/project.pbxproj
macos/Runner/Configs/AppInfo.xcconfig
linux/CMakeLists.txt
windows/runner/Runner.rc
```

`git ls-files | xargs grep -ln "com\.example"` で確認できる。
**iOSビルドは Windows では検証できない**ので `project.pbxproj` は目視確認のみ。

**2. アプリ表示名の統一** — iOS が `Wanote`、Android が `wanote` で不一致。
**PM未指定**。指定がなければ `wanote` に統一する

**3. `ios/Runner/Info.plist` に権限説明文4件**（PM承認済み）

| キー | 理由 |
|---|---|
| `NSCameraUsageDescription` | image_picker（**無いと撮影時にクラッシュする**） |
| `NSPhotoLibraryUsageDescription` | image_picker |
| `NSFaceIDUsageDescription` | local_auth |
| `NSUserTrackingUsageDescription` | google_mobile_ads（ATT） |

**4. 変更後の確認** — `flutter analyze` / `flutter test` / `flutter build apk`

### 保留中のプラン（着手指示待ち）

- **`PLAN_ads.md`** — 広告の表示タイミング。PM承認済み、**着手指示待ち**。
  Info.plist の4件はこのプランと同時に対応する想定だったが、
  バンドルID変更のついでに先行して入れてよい
- **`CLOUD_ACCOUNT_SETUP.md`** — アカウント発行手順。ステップ0の残り
  （表示名・サポートメール・プライバシーポリシーURL・個人/法人）が未決
- **`CLOUD_PHASE_TASKS.md`** — クラウドでしかできない作業28項目

### 環境の停止状態

シャットダウン前に以下を正常停止した。次回は `docker compose up -d` で戻る。

- Firebase エミュレータ（**`--export-on-exit` でデータを書き出し済み**。
  tour@wanote.local / ポチ / 証明書2件は保持されている）
- functions-dev（Worker）
- `:5000` 静的サーバー、`:5001` flutter run

---

## 0-B. 【解決済】スマホ/静的ビルドからログインできない（`f2e64a6`）

**2026-08-06 夜にPMから報告。2026-08-07 に原因特定・修正・検証完了。**

### 事象（PM報告）

スマホのブラウザから `:5000` にURL直接入力でアクセス。画面・機能は最新版だった。
写真登録中にメモリ関係で異常終了しホームに戻され、その後**再ログインできなかった**。
PM所感は「多重ログインの再発では」。

### 原因（確定）

**多重ログインではない。** Auth のリクエストが**本物の
`identitytoolkit.googleapis.com`** に飛んでおり、プレースホルダのAPIキーで
弾かれていた。アプリ側の文言は多重ログイン時と同じ汎用エラーなので見分けが
つかなかった。

前日の `2b1f44f` は「`initializeApp()` の前に sessionStorage に
エミュレータのoriginを書いておく」修正だったが、firebase_auth_web 側の
読み出しが

```dart
if (web.window.location.hostname == 'localhost' && kDebugMode)
```

でガードされているため、PMが実際に使った2つのケースには**どちらも効かなかった**:

- `flutter build web` の成果物（`:5000`）→ `kDebugMode` が false
- スマホからLAN IPでアクセス → hostname が `localhost` でない

### 修正（`f2e64a6`）

SDKを設定しようとするのをやめ、**リクエストの向き先を書き換える**方式に変更。
`lib/shared/config/emulator_web_support_web.dart`:

- `Firebase.initializeApp()` の前に `window.fetch` をラップし、
  `https://identitytoolkit.googleapis.com/...` と
  `https://securetoken.googleapis.com/...` をエミュレータへ振り替える。
  URLの形は `connectAuthEmulator` が生成するものと同一
  （`http://<host>:9099/identitytoolkit.googleapis.com/v1/...`）
- プラグインの内部実装に一切依存しないので、**リリースビルドでも
  localhost以外のホストでも効く**
- web では `useAuthEmulator()` の呼び出しを**やめた**（成功したふりをするだけなので）。
  Firestore / Storage は従来どおり `useXEmulator()` で接続（初期化後でも効く）
- エミュレータのホストは**ページを配信したホストに追従**するようにした。
  スマホが `http://192.168.0.63:5000` を開けば、エミュレータも
  `192.168.0.63:9099` を見に行く。`--dart-define=EMULATOR_HOST` は従来どおり優先
  （Androidエミュレータの `10.0.2.2` 用）

**トレードオフ**: これは正式APIではなくシム。JS SDK は自分がエミュレータに
繋がっていることを知らないので、「Running in emulator mode」の黄色いバナーは
出なくなった。**バナーが無い＝エミュレータ未接続、ではない**ので注意。

### 検証済み

- `:5001`（デバッグ）localhost → UIからサインイン成功、ホーム画面まで到達
- `:5000`（リリースビルド）localhost → 同上。Firestoreのデータも
  Storageの写真も表示された
- `:5000` / `:5001` を **LAN IP（192.168.0.63）** で開き、
  書き換え後のリクエストが `http://192.168.0.63:9099` に届き 200 が返ることを確認

### 残っている関連課題

- **AIバックエンドのホストは未対応**。`AI_BACKEND_BASE_URL` は
  `String.fromEnvironment` のままなので、スマホから使うならビルド時に
  LAN IP を渡す必要がある（下の起動コマンド参照）。
  エミュレータと同様に「ページを配信したホストに追従」させるのが筋だが、
  参照箇所が3つの feature に分かれているため未着手
- **写真登録でのメモリ異常終了そのものは未調査**。
  `image_picker` で取得したバイト列をリサイズせず保持しているため、
  スマホのブラウザで大きい画像を扱うとタブが落ちる可能性がある
- `_claimSession()` はローカル（localStorage）→ リモート（Firestore）の順に
  書くので、途中で異常終了するとローカルだけが進む。
  今回の原因ではなかったが、順序は見直したほうが安全
- ログイン失敗時の文言が汎用のもの1種類しかなく、
  「認証エラー」「多重ログイン」「設定不備」が区別できない。
  **今回の誤診の直接の原因**なので、開発ビルドだけでも原因コードを出したい

---

## 0-C. サーバの起動方法（:5000 と :5001 の両方）

### `:5001` — `flutter run`（ホットリロードあり、デバッグビルド）

```
flutter run -d web-server --web-port 5001 --web-hostname 0.0.0.0   --dart-define=USE_FIREBASE_EMULATOR=true   --dart-define=AI_BACKEND_BASE_URL=http://192.168.0.63:8787
```

- `--web-hostname 0.0.0.0` にしないとスマホから届かない
- **同時に開けるタブは1つだけ**。2つ開くと DWDS の WebSocket が奪い合いになり、
  `ws://.../$dwdsSseHandler failed` を繰り返してリロードループに入る
  （アプリの不具合ではない）

### `:5000` — 静的配信（リリースビルド、スマホ確認向け）

```
flutter build web --release   --dart-define=USE_FIREBASE_EMULATOR=true   --dart-define=AI_BACKEND_BASE_URL=http://192.168.0.63:8787
```

```
py -3 C:\Dev\docs	ools\serve_web.py 5000 C:\Dev\wanoteuild\web
```

- `serve_web.py` は 0.0.0.0 にバインドするのでスマホから届く
- **ビルドし直さないと変更が反映されない**。`:5001` と違いホットリロードは無い
- 以前あった「リリースビルドが真っ白」の問題は再現しなくなった。
  8/7 のビルドでは両ポートともサインインまで確認できている

LAN IP は変わることがあるので、起動前に確認すること:

```
powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL' -and $_.IPAddress -notmatch '^169\.' }).IPAddress"
```

---

## 0. 次回やること（優先順）

0. **【最優先】課金経路のサーバ側認可**（0-A3 の問題1・2）。
   実ユーザー投入の前提条件。Workerにサービスアカウントを持たせ、
   コード引き換えと利用枠の判定をサーバ側に移す

1. **機能確認 — 一部完了、UI確認が残っている**
   - 済: 生体認証・通知スケジュールを**テストで検証**（`20fa99f`）
   - 済: Androidビルド成功、196テストパス
   - 済: ブラウザ自動操作の手順を確立（0-A参照）。サインイン〜ホーム画面まで確認
   - **未: アイコン・背景のピンチ調整の実操作確認**（写真選択ダイアログを自動操作できない）。
     スマホ実機なら `:5000` を開いて手で確認できる（0-C 参照）
   - **未: Google/Apple サインイン、課金** — エミュレータでは検証不可。
     実アカウント・実ストアが要るのでクラウド接続後（手順3の後）に回す
2. デザイン修正
3. 各種クラウド環境の設定（実Firebase / RevenueCat / Anthropic APIキー）
4. Webブラウザでのローカル確認 → 実機確認

> **注意**: SDK更新でAPIが変わった Google サインイン・課金は、
> **実機テストで最初に確認すべき箇所**。コードは通っているが未実行。

**サーバの起動コマンドは 0-C にまとめてある。** `:5000`（リリースビルド）も
`:5001`（`flutter run`）も、8/7 時点で両方サインインまで動作確認済み。
「`flutter build web` の成果物が真っ白」の問題（後述 2.5）は再現しなくなった。

### 復旧ポイント
SDK更新前の状態は **タグ `v0.1-initial-build`** と **ブランチ `initial-build`**
（いずれも `57b2eab`）に保全済み。`git checkout initial-build` でいつでも戻せる。

---

## 1. 完了済み（コミット済み・対応不要）

### `7741e71` SDK一括更新（main へマージ済み）
クラウド接続・実機テストに備え、依存パッケージを現行メジャーへ更新。

| 更新 | 備考 |
|---|---|
| Firebase一式（core 3→4, auth 5→6, firestore 5→6, storage 12→13, messaging 15→16） | コード修正不要 |
| google_mobile_ads 5→9 | **Androidビルドを阻害していた**（Gradle非互換）。コード修正不要 |
| google_sign_in 6→7 | **API全面刷新**。シングルトン化・`authenticate()`・accessToken廃止に対応 |
| local_auth 2→3 | `AuthenticationOptions` 廃止、`stickyAuth`→`persistAcrossBackgrounding` |
| purchases_flutter 8→10 | `purchasePackage` の戻り値が `PurchaseResult` に |
| flutter_local_notifications 18→22 | 全引数が名前付きに、`uiLocalNotificationDateInterpretation` 廃止 |
| sign_in_with_apple 6→8 / flutter_secure_storage 9→10 / fl_chart 0.69→1.2 / timezone 0.9→0.11 | コード修正不要 |

`intl` は `flutter_localizations` が 0.20.2 に固定しているため据え置き。

**Androidビルドが通るようになった**（更新前は2つの問題でAPKが生成できなかった）。
`android/app/build.gradle.kts` に core library desugaring を追加している。

**残課題**: `Purchases.purchasePackage` が非推奨（`purchase(PurchaseParams)` 推奨）。
動作はするがanalyzerにinfoが2件出る。`PurchaseParams` がビルダー経由のため別途対応。

### `0e61c46` 日本語未翻訳の修正
PMレビューで指摘された「日本語欄が英語のまま」の項目を `lib/l10n/app_ja.arb` で48キー修正済み。
`flutter gen-l10n` 再生成・ビルド確認済み。

### `1df6dd7` 生SDKエラーの画面表示を停止
Firebase/RevenueCat SDK が返す生のエラー文字列を画面に出さず、`dart:developer` の
開発者向けログにのみ出力するよう変更。画面には汎用のローカライズ済みメッセージのみ表示。

> **注意**: この修正は一度「完了」と報告したが、実際にはWebビルドに反映されていなかった。
> ソース修正自体は正しく、クリーン再ビルド後に画面上での解消を確認済み。
> **同種の作業では必ず再ビルド後の実挙動まで確認すること。**

### メッセージ一覧Excel（`docs/wanote_messages.xlsx`）とARBへの反映
- G列「修正後」・H列「説明の日本語訳」を追加、計68行に記入済み
- 全320行を機械スキャンし、未対応の未翻訳セルが**0件**であることを確認済み
- `emailLabel` / `orDivider` / `passwordLabel` の3件はPM判断により**対応不要**
  （日本語UIでも一般的な表記のため）。G列にその旨を記載、ARBも変更していない

**ARB（プログラム）への反映状況: 68件中65件反映済み・対応不要3件・未反映0件**

| 回 | 内容 | 反映コミット |
|---|---|---|
| 1回目 | 赤セル指摘 56件 | `0e61c46` |
| 2回目 | G列 48,53,57,65,78,105,110,112,114 の9件 | `ec601c0` |

`noProductsAvailableMessage` は英語原文にも内部実装の話
（"The RevenueCat dashboard has not been configured..."）が混入していたため、
英語側も一般的な文言に修正した（黄色セル175行目の "spec 3.4" と同種の問題）。

> 検証コマンド（ExcelのG列と app_ja.arb を突き合わせ、未反映を検出する）:
> `docs/tools\verify_arb_against_excel.py` を `py -3` で実行。

---

## 2. 未完了・引き継ぎ事項

### ~~【最優先】重複ログイン対策の不具合~~ → `ec601c0` で原因特定・修正完了

**PM報告の症状**: ログイン後、ブラウザの戻るボタンを押してログイン画面に戻ると、
正しいパスワードを入力してもエラーになる。

**確定した原因**（再現テストで決定的に実証済み）:

多端末ログイン制御が**自分自身のログインと競合**していた。

`watchActiveSessionId()` の実体は Firestore の `snapshots()` で、
**購読した瞬間にドキュメントの「現在値」を全リスナーに再生する**。
一方 `_runAuthAction` は「購読 → その後にセッション確保」の順だったため、

1. 購読 → 再生される値は**前回のセッションID**
2. `_claimSession` がローカル(prefs)に**新しいセッションID**を書く
3. リスナーが「新ローカル ≠ 旧リモート」を検知
4. **別端末が乗っ取ったと誤判定し、ログイン成功直後に自分をサインアウト**

**初回ログインだけ成功していた理由**: 新規アカウントは再生値が `null` で、
リスナーが `null` を無視するため。これが「1回目は通り、2回目で正しい
パスワードが弾かれる」という非対称な症状の正体。

**修正内容（2点セット。片方だけでは直らないことをテストで確認済み）**:
1. **確保してから購読する**。`_claimSession` を `_onAuthChanged` 内へ移動し、
   `getOrCreate()` の後（＝アカウントdocが存在する。前に戻すと以前の
   NOT_FOUND バグが再発する）かつウォッチャ設置の前に配置。
2. **世代カウンタでガード**。Firebase Auth はサインイン成功時に
   `authStateChanges()` も発火するため `_onAuthChanged` が並行に2回走る。
   順序修正だけではストリーム側の購読が stale 値を掴むため、
   `_sessionGeneration` を購読時に捕捉し、確保後に古い購読を無効化する。

**回帰テスト**: `test/features/auth/presentation/auth_controller_session_race_test.dart`
実Firestoreの「購読時に現在値を再生する」挙動を再現する fake を持つ。
既存テストがこれを再現していなかったことが、バグ見逃しの原因だった。

> **未実施**: 実機（ブラウザ）での最終確認。ブラウザ自動操作ツールが
> 壊れているため（後述）、検証は単体テストのみ。PMに手動確認を依頼するか、
> ツール問題の解消後に確認すること。
> 検証用アカウント: `repro-1785940739@wanote.local` / `ReproPass1!`

---

### 【重要】ブラウザ自動操作ツールの障害（調査の妨げになっている）

再現確認が進まない直接の原因。以下を確認済み:

- Flutterのクリック判定領域 `flt-glass-pane` の
  `getBoundingClientRect()` が **0×0** を返す状態になっている
  （canvas自体は375×812で正常描画されている）
- そのため `computer` ツールのクリックが座標に当たらず、毎回30秒でタイムアウト
- タブ再作成・リサイズ・リロードを試したが解消せず
- ページ読み込みのたびに未処理例外が2件発生している（内容未特定・要調査）

→ 座標クリックに依存しない検証手段（後述のintegration_test、または
  JS経由での直接操作）に切り替えるのが現実的。

---

### ~~【保留】全画面スクリーンショット取得（日英）~~ → 完了（40枚）

**成果物**: `docs/wanote_messages.xlsx` の **「画面一覧」シート**に、
20画面 × 日英 = **40枚**を並べて埋め込み済み（差分ゼロ）。
PNG実体は `docs/screenshots\`（751×1624・実フォント）。

**撮影した20画面**: サインイン / パスワード再設定 / アカウント作成 /
言語選択（認証・設定の2箇所）/ サインイン入力済み / ペットプロフィール /
ホーム / 日常記録（健康・体重・トイレ）/ 医療（通院・薬・予防・証明書）/
AI（相談・レポート）/ 設定 / ペット切替 / 有料プラン

**採用した方式（重要）**: integration_test は断念し、
**Flutterのセマンティクス（アクセシビリティ）DOMを有効化してJSから操作**する方式に変更。
再現手順とツールキットは `docs/tools\tour_toolkit.js` に保存。

なぜこの方式か:
- `flutter test -d chrome` はWebでintegration_test非対応
- `flutter drive` + chromedriver も `AppConnectionException` で失敗
- ブラウザツールの座標クリックは `flt-glass-pane` が0×0のため機能しない
- `<flutter-view>` への合成PointerEventもFlutterのジェスチャに届かない
- → **`flt-semantics-placeholder` をクリックしてセマンティクスDOMを生成させ、
  `role=button/tab` のノードを `.click()` する**とFlutterのonTapに到達する

**既知の注意点**:
- テキスト入力はJSでの `value` 代入が **Flutterに上書きされる**。
  JSでフィールドをフォーカス＋全選択し、**実キー入力**（ブラウザツールの`type`）を送ること。
- ページ再読込でツールキットは消える。毎回再注入が必要。
- **Docker再起動直後の初回読込はエミュレータ接続に失敗する**ことがある
  （`.firebase-emulator-warning` バナーの有無で判定できる）。1回リロードすれば直る。

**追加撮影済み**: ダイアログ6種（日付／時刻／写真選択シート／体重追加／排尿記録／
ペット削除確認）と入力フォーム7種（健康記録・排便・通院・投薬・予防プログラム・
予防投与記録・給餌量計算）。**計33画面 × 日英 = 66枚**。

---

### ~~【要調査】証明書の画像が表示されない~~ → `c207dc0` で原因特定・修正完了

PM報告「証明書の画像が一覧、詳細ともに表示されていません」。
**原因は2つあり、別物だった。**

**1. 詳細（全プラットフォームで発生）**
`PreventionRecordFormScreen` は、新しく選んだ画像は `Image.memory` で描画するのに、
**保存済みの証明書は「登録済みの証明書があります」という文字を出すだけで、
画像ウィジェットが存在しなかった**。→ 画像を描画するよう修正。

**2. 一覧（Webのみ）**
`_CertificateImage` がファイルキャッシュ経由のみで描画していた。キャッシュは
`path_provider` の `getApplicationDocumentsDirectory()` に依存しており、
**Webでは未実装のため必ず失敗**し、全カードが壊れた画像アイコンになっていた。
→ キャッシュが使えない場合は Storage URL に **フォールバック**するよう修正。
モバイルは従来どおりキャッシュ優先なので、spec 5.3 のオフライン提示用途は不変。

**調査中の教訓（誤った見立て）**: 当初「一覧が空」と判断し `orderBy` を疑ったが、
診断ログで `total=2 withCert=2` と判明。**一覧は空ではなく画像だけが出ていなかった**。
`orderBy` は無関係だったため変更を差し戻した。UIの見た目だけで原因を推測せず、
件数をログに出して確認するのが早い。

**ツアー用アカウント**: `tour@wanote.local` / `TourPass1!`
（エミュレータはDocker再起動でデータが消えるため、都度作り直しが必要）

---

## 2.5 ~~【要判断】Webのリリースビルドが起動しない~~ → 再現しなくなった

`flutter build web` の成果物が真っ白になる事象。原因は
「`Firebase.initializeApp()` の Future が永久に完了しない（dart2jsビルドのみ）」
と特定していたが、**2026-08-10 のビルドでは再現しない**。
`:5000` で静的配信したリリースビルドが正常に起動し、
サインイン→ホーム画面まで到達することを確認済み（0-B / 0-C 参照）。

原因が消えたのか条件次第で再発するのかは**未確定**。再発したら当時の切り分け結果が
役に立つので、以下は記録として残す。

<details>
<summary>当時の調査記録</summary>

**原因（計測により確定）**: `Firebase.initializeApp()` の Future が永久に完了しない。
`.timeout(8秒)` で包むと例外ではなく `TimeoutException: Future not completed`。
初期化処理そのものは成功しており、強制的に先へ進めると正常に描画された。

**発生条件**: リリースビルド（dart2js）のみ。`flutter run`（dartdevc）では発生せず。

**切り分け済み（すべてシロ）**: 自分たちのコード（以前正常だった `c207dc0` でも再現）／
Dockerエミュレータ／ブラウザペイン／クリーンビルド／CanvasKit／静的サーバー／
ブラウザキャッシュ／Service Worker／通知許可／`--no-wasm-dry-run`。

**効果がなかった対処**: FlutterFireの最新化（`477f528`）、Service Workerの追加（差し戻し済み）。

**関連事実**: `navigator.serviceWorker.ready` がこの環境では永久に解決しない。
`firebase_messaging_web` がこれを待っている疑いがあったが未確定。

</details>

---

## 2.6 【判断済・保留】画面遷移のフェードと残像

**事象**: 画面遷移時に、退場する画面がフェードしながらスライドし、
**全画面の情報が残像として残る**（PM報告）。

**重要**: これは **iOS の Safari で観測されたもの**。Flutter Web は canvas の
合成方法がネイティブの Metal/Impeller と異なるため、**web固有の描画アーティファクト
である可能性が高い**（未検証）。

**一度は対処したが差し戻した**:
- `8266922` — アプリ全体でページ遷移をアニメーションなしにした
- `47b5990` — Android の predictive back を残しつつ前進のpushだけ即時にした

**差し戻した理由**（PM判断）: この対処は
**Androidのpredictive back と iOSのスワイプバック（画面端から戻るジェスチャ）を
両方犠牲にする**。ネイティブ配布のみを想定しており、ネイティブでは再現しない
可能性があるため、**実機で確認してから対処するか判断する**。

**現状**: `pageTransitionsTheme` は指定していない（＝各プラットフォームの既定動作）。
`test/app/page_transitions_test.dart` が、うっかり上書きし直したときに
気づけるよう2つのジェスチャを固定している。

**次にやること**: iOS / Android の実機で遷移を確認する。
- 再現しない → 対処不要。この節を閉じる
- 再現する → `git show 8266922 47b5990` の実装を戻す。
  そのとき**何を失うか**（上記2つのジェスチャ）を承知の上で判断すること

**なお `android:enableOnBackInvokedCallback="true"` はマニフェストに残してある**
（`47b5990`）。これが無いと predictive back はテーマの指定に関わらず動かない。
差し戻しとは独立に必要な設定。

---

## 3. 環境の状態

| 項目 | 状態 | 再開時の操作 |
|---|---|---|
| Docker（Firebaseエミュレータ） | **起動したまま** (healthy) | そのまま使える。落ちていたら `docker compose up -d` |
| 静的サーバ :5000 | 起動したまま | 落ちていたら `build/web` で `python -m http.server 5000 --bind 0.0.0.0` |
| スクリーンショット受信 :5050 | 起動したまま | 落ちていたら `py -3 docs/tools\shot_receiver.py` |
| chromedriver :4444 | **停止済み** | 必要時 `C:\...\scratchpad\chromedriver-win64\chromedriver.exe --port=4444` |
| バックグラウンドエージェント | **全て終了済み** | 稼働中のものはなし |

Firestoreのセキュリティルール（`firestore.rules`）は**エミュレータ用の全開放のまま**。
本番用ルールの作成は未着手（CLAUDE.mdの要件、別タスク）。

### Webビルドコマンド（emulator向け）
```bash
flutter build web --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.0.63 --dart-define=AI_BACKEND_BASE_URL=http://192.168.0.63:8787
```

---

## 4. 保全した資産

| パス | 内容 |
|---|---|
| `docs/wanote_messages.xlsx` | メッセージ一覧（G/H列記入済み・最新） |
| `docs/tools\fix_excel.py` | Excel G/H列生成スクリプト（全訳文を保持） |
| `docs/tools\fix_arb.py` | app_ja.arb への翻訳適用スクリプト |
| `docs/tools\build_messages_excel.py` | ARBからExcelを生成 |
| `docs/tools\shot_receiver.py` | スクリーンショット受信サーバ(:5050) |
| `docs/screenshots\` | 取得済みスクリーンショット2枚 |

> Pythonは `py -3` で起動すること（`python3` は使用不可）。
> 日本語出力時は `PYTHONIOENCODING=utf-8` を付けること。

### Git状態
- `main` = `0e61c46`、**作業ツリーはクリーン**
- スクリーンショットツアーのWIPは worktree ブランチ
  `worktree-agent-ac5205add01d7ec9a` の `017305f` に保全済み
  （動作未確認のため main には未マージ）
