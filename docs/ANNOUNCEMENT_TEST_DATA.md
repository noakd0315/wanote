# お知らせのテストデータ

作成: 2026-08-15
対象: [VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md) の確認と併せて

**日英の出し分けは実装済みです。** このファイルは、それを実機で確認する
ためのデータです。

---

# なぜ私が登録できないか

`announcements` は **Firebase コンソールからしか書けません。**

```
match /announcements/{id} {
  allow read: if true;
  allow write: if false;   // ← アプリからは一切書けない
}
```

自分でお知らせを投稿できるアプリは、そのお知らせが信用できません。
意図的にこうしてあります（[`firestore.rules:104`](../firestore.rules)）。

私がサービスアカウントを持てば書けますが、**その鍵は私に渡さない**
取り決めです。**以下をコンソールに貼り付けてください。5件で10分ほどです。**

---

# 本番のお知らせを作るとき

**このファイルはテスト用データです。** 実際にお知らせを出すときは、
別セッションで `/announcement` と入力してください。日本語の文面から
英語版を作り、**その英語の意味を日本語に訳し戻して確認**したうえで、
貼り付け用の登録内容まで組み立てます（`.claude/skills/announcement/`）。

---

# 登録のしかた

Firebase コンソール → **Firestore Database** → コレクション
`announcements` → **ドキュメントを追加**

- ドキュメントIDは **自動ID**で構いません
- フィールドは**下の表のとおりの型**で入れてください
  （`published_at` / `expires_at` は **timestamp**、`important` は **boolean**）
- 🔴 **型を string にすると意図どおり動きません**（日付が文字列でも一応
  読めますが、コンソールの日付ピッカーを使うのが確実です）

---

# ① 通常のお知らせ（日英あり）

**言語の出し分けを見るための本命です。**

| フィールド | 型 | 値 |
|---|---|---|
| `title_ja` | string | `アプリを更新しました` |
| `body_ja` | string | `予防医療の記録で、予防接種と投薬で入力欄が変わるようになりました。ワクチンの種類、または薬品名と用量を登録できます。` |
| `title_en` | string | `App updated` |
| `body_en` | string | `Preventive care records now ask what the care actually needs: the vaccine type for a vaccination, or the drug name and dose for a medication.` |
| `published_at` | timestamp | `2026-08-14 09:00` |
| `expires_at` | timestamp | `2026-12-31 23:59` |
| `important` | boolean | `false` |

---

# ② 重要なお知らせ（サインイン画面にも出る）

| フィールド | 型 | 値 |
|---|---|---|
| `title_ja` | string | `メンテナンスのお知らせ` |
| `body_ja` | string | `8月25日 2:00〜4:00 にメンテナンスを行います。この間、AI相談はご利用いただけません。` |
| `title_en` | string | `Scheduled maintenance` |
| `body_en` | string | `Maintenance on 25 August, 02:00-04:00. AI consultation will be unavailable during this time.` |
| `published_at` | timestamp | `2026-08-15 12:00` |
| `expires_at` | timestamp | `2026-08-26 00:00` |
| `important` | boolean | **`true`** |

> 🔴 **`important` が true のものはサインイン画面にも出ます。**
> 本番では**サインインできない障害のときだけ**にしてください。常時何か
> 出ている状態は、初回利用者の離脱要因になります。

---

# ③ 日本語だけ（英語フォールバックの確認）

**英語表示のまま、これだけ日本語で出れば正常です。**

| フィールド | 型 | 値 |
|---|---|---|
| `title_ja` | string | `年末年始のお問い合わせ対応について` |
| `body_ja` | string | `12月29日から1月3日まで、お問い合わせへの返信をお休みします。` |
| `published_at` | timestamp | `2026-08-13 10:00` |
| `expires_at` | timestamp | `2026-12-31 23:59` |
| `important` | boolean | `false` |

`title_en` / `body_en` は **作らないでください。** 欠けたときの挙動を見る
のが目的です。

---

# ④ 期限切れ（表示されないことの確認）

| フィールド | 型 | 値 |
|---|---|---|
| `title_ja` | string | `【表示されたら不具合】期限切れのお知らせ` |
| `body_ja` | string | `このお知らせが画面に出ていたら、expires_at が効いていません。` |
| `title_en` | string | `[BUG IF VISIBLE] Expired notice` |
| `body_en` | string | `If you can see this, expires_at is not being honoured.` |
| `published_at` | timestamp | `2026-08-01 09:00` |
| `expires_at` | timestamp | **`2026-08-10 09:00`** |
| `important` | boolean | `false` |

---

# ⑤ 予約投稿（まだ表示されないことの確認）

| フィールド | 型 | 値 |
|---|---|---|
| `title_ja` | string | `【表示されたら不具合】9月からのお知らせ` |
| `body_ja` | string | `このお知らせが9月1日より前に出ていたら、published_at が効いていません。` |
| `title_en` | string | `[BUG IF VISIBLE] September notice` |
| `body_en` | string | `If you can see this before 1 September, published_at is not being honoured.` |
| `published_at` | timestamp | **`2026-09-01 09:00`** |
| `expires_at` | timestamp | `2026-12-31 23:59` |
| `important` | boolean | `false` |

---

# 確認項目

## 日本語表示で

- [ ] ホームの上部にお知らせのバナーが出る
- [ ] 設定 → お知らせ で一覧が開く
- [ ] 🔴 **①②③の3件が出て、④⑤は出ていない**
- [ ] ②に**警告アイコン**が付いている
- [ ] 日付が **2026年8月14日** のような和暦形式で出る
- [ ] バナーを閉じられる
- [ ] アプリを開き直すと**また出る**（消えたままにはならない）

## 英語表示に切り替えて

- [ ] 🔴 **①と②が英語になる**（`App updated` / `Scheduled maintenance`）
- [ ] 🔴 **③は日本語のまま**（英語版が無いため。これが正常です）
- [ ] 日付が **Aug 14, 2026** 形式になる
- [ ] ④⑤は英語表示でも**出ない**

## サインアウトして

- [ ] 🔴 **サインイン画面に②だけ**が出る（`important: true` のもの）
- [ ] ①③は**出ない**

## 後片付け

- [ ] 確認が終わったら **④⑤を削除**（紛らわしいため）
- [ ] ①〜③は残しても構いません（期限切れで自動的に消えます）

---

# 実装状況

**日英の出し分けは 8/12 の実装時点から入っています。** 今回の依頼で
新しく作ったものはありません。

| | 実装 |
|---|---|
| モデル | [`announcement.dart`](../lib/shared/models/announcement.dart) の `titleFor(languageCode)` / `bodyFor(languageCode)` |
| 一覧画面 | [`announcements_screen.dart:21`](../lib/app/announcements_screen.dart) で `Localizations.localeOf` を参照 |
| バナー | [`announcement_banner.dart:121`](../lib/shared/widgets/announcement_banner.dart) で同上 |
| フォールバック | 英語版が無い／空文字のとき日本語へ。テスト済み |

ユニットテストは [`test/shared/announcement_test.dart`](../test/shared/announcement_test.dart)
に10件あり、英語切り替え・欠落時のフォールバック・空文字のフォールバック・
公開前・期限切れをすべて押さえています。

**このファイルのデータは、それが実機でも成り立つことを確認するためのもの
です。**
