# 次に再開するときの作業整理

最終更新: 2026-08-16 22:37

**このファイルから読んでください。** 何が終わっていて、次に何をするかだけを
書いてあります。詳細は各リンク先へ。

---

# 🔴 まず最初にやること

## 1. TestFlight を最後まで通す（10分・待ち時間あり）

**iOSビルドは 8/16 夜に成功しました。** あと2手でiPhoneに届きます。

- [ ] App Store Connect → **wanote** → **TestFlight** タブ
- [ ] ビルドの処理完了を確認（5〜30分。「処理中」が消える）
- [ ] 🔴 **輸出コンプライアンスの質問に回答**
      → 「暗号化を使用していますか」に **いいえ**
      （HTTPS のみで独自の暗号化は実装していません。申告はPM判断です）
- [ ] **内部テスト**グループにビルドが入っているか確認（自動で入らなければ手動追加）
- [ ] iPhoneの **TestFlight** アプリを開く → **wanote** が出る

> **回答するまで配信されません。** ここで止まりがちです。
> 内部テストは審査不要なので、回答すればすぐ届きます。

## 2. Codemagic の環境変数を1つ更新（3分）

- [ ] `GOOGLE_SERVICE_INFO_PLIST_BASE64` を新しい値に差し替え

Googleログインを有効化したことで `GoogleService-Info.plist` に `CLIENT_ID` が
追加され、ローカルは更新済みですが **CIの変数が古いまま**です。このままだと
CIが古い内容で上書きし、**iOSのGoogleログインだけ動きません**（ビルドは通ります）。

値の場所は「値の置き場所」の節を参照。

---

# 今日（8/16）終わったこと

## アプリの修正（実機に反映済み）

| | 内容 |
|---|---|
| 二重ログイン | サインイン中の自分の claim を乗っ取りと誤認していた |
| ログイン後の画面 | サインインごとにシェルを作り直し、ホームで開く |
| アプリ再起動 | 開き直したらホームタブへ（押し込んだ画面はそのまま） |
| AI相談への自動遷移 | 血便の記録が毎回AI相談を開いていた。バナーのボタンのみに |
| お知らせ | フィールド名の空白・タブを吸収。`orderBy` による除外も解消 |
| アカウント削除の導線 | ログアウトから離し、行に「すべての記録と写真が消えます」 |
| Googleログイン | Firebase設定済み・`google-services.json` 反映済み |

## iOS ビルド基盤（今日いちばん時間を使った所）

**署名は完全に解決済みです。証明書とプロファイルはApple側に保存されている
ので、次回以降は再利用されます。ここでもう詰まりません。**

潰した順:

1. プロファイルが作られない → `--create` を追加
2. `ios_signing` の自動署名が新規アカウントで通らない → ブロックごと削除
3. `config/prod.json` がCIに無い → 環境変数から復元
4. 証明書の秘密鍵が無い → `CERTIFICATE_PRIVATE_KEY` を追加
5. iOS 最低バージョンが 13.0 → **15.0** へ（Firebaseの要求）

あわせて、変数が欠けていたら**変数名を名指しして止まる**ようにしました。
以前は空ファイルが黙って作られ、ずっと後で別の問題に見えていました。

---

# 残作業（アプリ環境）

| | 内容 | 着手 |
|---|---|---|
| **AdMob** | 6つのID。ユニット4つ→`config/prod.json`、アプリ2つ→`AndroidManifest.xml`/`Info.plist`。iOSは SKAdNetwork も | **すぐ可** |
| **Sign in with Apple** | Firebase Auth で Apple を有効化（Services ID / Key ID / `.p8`）。App ID 側は登録済み | **すぐ可** |
| **RevenueCat** | 公開SDKキー2つ（`goog_`/`appl_`）→ `config/prod.json` | 商品登録が前提 |

**アプリ側の実装はGoogle・Appleとも完了しています。** 残っているのは外部
サービスの設定と、その値をアプリに渡すことだけです。

# 残作業（公開まで）

`docs/RELEASE_SETUP_STEPS.md` に手順があります。順番に制約があります。

```
署名鍵 → AABを内部テストへ → 商品登録が解禁 → RevenueCat接続
```

🔴 **Play の「12人 × 14日」が日程の律速**です。9/30 に間に合わせるには
**9月上旬までにクローズドテストを開始**する必要があります。テスター12人の
確保（家族・友人可）も並行して進めてください。

---

# 実機テスト

`docs/VERIFICATION_CHECKLIST.md`（第3回・A〜K章）。

- A章に 8/16 の修正分（A-9〜A-11）を追加済み
- **I章（削除）はまとまった時間があるときに。** 消え残りがあると個人情報の
  保持になり、調査にFirebaseの状態が要ります

---

# 値の置き場所

Codemagic の環境変数（グループ `wanote_ios`、すべて Secure）:

```
GOOGLE_SERVICE_INFO_PLIST_BASE64   ← 🔴 更新が必要
FIREBASE_OPTIONS_DART_BASE64
PROD_JSON_BASE64
CERTIFICATE_PRIVATE_KEY
```

base64 の3つは**いつでも再生成できます**（元ファイルがローカルにあるため）:

```
base64 -w0 ios/Runner/GoogleService-Info.plist
base64 -w0 lib/firebase_options.dart
base64 -w0 config/prod.json
```

🔴 **`cert_key.pem` だけは再生成できません。** 配布証明書と対になっている
秘密鍵で、Codemagic の Secure 変数は読み出せません。アップロード鍵と同じ
場所に保管してください（PMが退避済み）。

---

# 参照するドキュメント

| ファイル | 何が書いてあるか |
|---|---|
| `docs/VERIFICATION_CHECKLIST.md` | 実機テストの確認事項（第3回） |
| `docs/RELEASE_SETUP_STEPS.md` | 署名鍵→課金→広告の手順。順番に意味あり |
| `docs/CLOSED_TEST_GUIDE.md` | 申請とクローズドテストの流れ |
| `docs/BACKLOG.md` | 後回しにしているもの |
| `docs/ANNOUNCEMENT_TEST_DATA.md` | お知らせのテストデータ（①のみ登録済み） |

お知らせを作るときは、別セッションで `/announcement` と入力してください。
