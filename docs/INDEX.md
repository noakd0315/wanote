# wanote ドキュメント一覧

最終更新: 2026-08-14

**迷ったらここから。** 目的別に並べてあります。

---

## 🔵 いま読むもの

| ファイル | 何が書いてあるか |
|---|---|
| **[STATUS.md](STATUS.md)** | **完了／未了の一覧。まずこれ** |
| **[SESSION_HANDOVER.md](SESSION_HANDOVER.md)** | 作業の引き継ぎ。日付順の全経緯 |
| **[PLAN_implementation_first.md](PLAN_implementation_first.md)** | **着手順はこれが正**。申請より実装を優先する方針（PM指示） |
| **[ANDROID_DEVICE_TEST_GUIDE.md](ANDROID_DEVICE_TEST_GUIDE.md)** | **次にやること**。実機テストの手順と確認項目 |
| **[BACKLOG.md](BACKLOG.md)** | **後回しにしているものの一覧**。判断済み・着手待ち・意図的な見送りを理由つきで |

---

## PM が作業するとき

| ファイル | 用途 | 状況 |
|---|---|---|
| [CLOUD_SETUP_CHECKLIST.md](CLOUD_SETUP_CHECKLIST.md) | クラウド各社の登録一覧 | AdMob のみ残 |
| [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) | Firebase の詳細手順 | ✅ 完了 |
| [SETUP_STEPS_ANTHROPIC_CLOUDFLARE.md](SETUP_STEPS_ANTHROPIC_CLOUDFLARE.md) | Anthropic → Cloudflare の詳細手順 | ✅ 完了 |
| [CODEMAGIC_SETUP.md](CODEMAGIC_SETUP.md) | iOSビルド用CIの設定 | ✅ `verify` 稼働中／iOS は Apple 承認待ち |
| [CLOSED_TEST_GUIDE.md](CLOSED_TEST_GUIDE.md) | 申請とクローズドテストの流れ（Android / iOS） | 未着手 |

---

## ストア提出物

| ファイル | 用途 | 状況 |
|---|---|---|
| [PRIVACY_POLICY_DRAFT.md](PRIVACY_POLICY_DRAFT.md) | ポリシー本文と申し送り | 事業者名記入済み |
| `wanote/site/privacy-ja.html` | **公開用ページ（日本語）** | ✅ 作成済み・未公開 |
| `wanote/site/privacy-en.html` | **公開用ページ（英語）** | ✅ 作成済み・未公開 |
| [STORE_LISTING_DRAFT.md](STORE_LISTING_DRAFT.md) | ストア掲載文（日英） | ✅ 草案 |
| [DATA_SAFETY_DECLARATION.md](DATA_SAFETY_DECLARATION.md) | データセーフティ / App のプライバシー申告 | ✅ 回答集 |

> 🔴 **ポリシーは未公開です。** Play も App Store も**公開URLが必須**なので、
> Cloudflare Pages への配置が申請の前提になります。

---

## 設計・計画

| ファイル | 内容 | 状況 |
|---|---|---|
| [dog_health_app_spec.md](dog_health_app_spec.md) | **元の仕様書** | — |
| [PLAN_ads.md](PLAN_ads.md) | 広告の表示タイミング | ✅ 実装済み |
| [PLAN_referral_reward.md](PLAN_referral_reward.md) | 紹介特典・保留付与 | ✅ 実装済み |
| [PLAN_push_reminders.md](PLAN_push_reminders.md) | リマインダーのプッシュ化 | ⏸ **PM判断で保留** |
| [CLOUD_PHASE_TASKS.md](CLOUD_PHASE_TASKS.md) | クラウド/実機でしかできない作業の一覧 | 進行中 |

---

## 現在の状態（2026-08-14 時点）

### 動くもの

| | |
|---|---|
| Firebase（認証・DB・画像） | ✅ 本番プロジェクト `wanote-7dca0` |
| セキュリティルール | ✅ **本番で実データ確認済み** |
| バックエンド（Cloudflare Worker） | ✅ デプロイ済み |
| AI（相談・レポート・OCR） | ✅ **実キーで応答確認済み** |
| リマインダー | ✅ 実装済み（**実機未検証**） |
| 広告 | ✅ 実装済み（テストID・**実機未検証**） |
| お知らせ | ✅ 実装済み（**実機未検証**） |
| アカウント削除 | ✅ 実装済み（**実機未検証**） |
| Android リリースビルド | ✅ APK生成確認済み |

### 未了

| | ブロッカー |
|---|---|
| **Android 実機テスト** | **なし。いつでも可能** |
| 本番の広告ID | AdMob 未登録 |
| 課金 | RevenueCat（ストア申請待ち） |
| iOS ビルド | 🔴 **Apple Developer Program のみ**（他は完了） |
| Google / Apple サインイン | 未設定 |
| ポリシーの公開 | Cloudflare Pages への配置 |

### テスト

| | |
|---|---|
| Flutter | 321件 |
| Worker | 119件 |
| セキュリティルール | 77件 |
| `flutter analyze` | 0件 |

---

## 🔴 忘れると詰むもの

| | なぜ |
|---|---|
| **`api.wanote.jp` の設定** | バックエンドURLは**ビルド時に埋め込まれ、出荷後は変更できない** |
| **アップロード鍵のバックアップ** | 失うと**二度とアプリを更新できない** |
| **Play の 12人×14日** | **短縮不可**。9月上旬には開始したい |
| **Sign in with Apple** | 無いと **iOS はリジェクトされる** |
| **ポリシーと実装の一致** | 公開直前に両方向で突き合わせる（`PRIVACY_POLICY_DRAFT.md` A2） |
