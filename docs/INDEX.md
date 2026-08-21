# wanote ドキュメント一覧

最終更新: 2026-08-22

**迷ったらここから。** 文書は3つに分けてあります。

| | どういうものか | 場所 |
|---|---|---|
| 🔵 **これから対応するもの** | 未着手・進行中の作業。**ここだけ見れば残りが分かる** | このフォルダ |
| 📗 **手順書・参照資料** | 作業のたびに開くもの。終わりのある作業ではない | このフォルダ |
| 📦 **完了済みの記録** | 済んだ作業の経緯。読まなくても進められる | [`archive/`](archive/) |

---

# 🔵 これから対応するもの

**まずこの3つ。他は必要になったときで足ります。**

| 文書 | 中身 | 見るとき |
|---|---|---|
| [SESSION_HANDOVER.md](SESSION_HANDOVER.md) | **再開したら最初に読む。** 今どこにいるか、次に何をするか | 毎回 |
| [REMAINING_WORK.md](REMAINING_WORK.md) | 公開までに必要な残作業の一覧 | 週の頭、申請前 |
| [BACKLOG.md](BACKLOG.md) | 後回しにした判断と、公開前に確認が要る事項 | 「あれどうなった？」のとき |

その他:

| 文書 | 中身 | 状態 |
|---|---|---|
| [TESTER_RECRUITMENT.md](TESTER_RECRUITMENT.md) | テスター募集（Instagram + Google フォーム） | クローズドテストを業者に依頼する方針のため、**使うかは未定** |
| [DATA_SAFETY_DECLARATION.md](DATA_SAFETY_DECLARATION.md) | データセーフティ申告（Play）/ App のプライバシー | **申告はこれから。** 申告内容は確定済み |
| [PLAN_push_reminders.md](PLAN_push_reminders.md) | リマインダーをプッシュ通知にする検討 | **未着手。** 現在はローカル通知で動作中 |
| [VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md) | 実機での通し確認リスト（第3回） | 公開前の総ざらいに再利用できる |

---

# 📗 手順書・参照資料

## ストア・課金の設定

| 文書 | 中身 |
|---|---|
| [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md) | RevenueCat の設定手順。**両ストアの商品登録から通しで書いてある**。困ったときの見分け方も末尾に |
| [RELEASE_SETUP_STEPS.md](RELEASE_SETUP_STEPS.md) | 出荷準備（署名 → 課金 → 広告）の手順 |
| [PRICING.md](PRICING.md) | **課金価格はこれが正。** 手順書の記入例と混同しないこと |
| [CLOSED_TEST_GUIDE.md](CLOSED_TEST_GUIDE.md) | クローズドテストの進め方（Play / TestFlight） |
| [ADS_AND_BILLING_IN_TEST.md](ADS_AND_BILLING_IN_TEST.md) | 広告と課金を、テスト段階でどこまで有効にするか |

## ビルド・動作確認

| 文書 | 中身 |
|---|---|
| [ANDROID_DEVICE_TEST_GUIDE.md](ANDROID_DEVICE_TEST_GUIDE.md) | Android 実機へ入れて確認する手順 |
| [CODEMAGIC_SETUP.md](CODEMAGIC_SETUP.md) | iOS ビルドと TestFlight 配信（Mac 不要）。**iOS は手動起動のみ** |
| [local_dev.md](local_dev.md) | ローカル開発環境の起動方法 |

## 掲載・法務

| 文書 | 中身 |
|---|---|
| [STORE_LISTING_DRAFT.md](STORE_LISTING_DRAFT.md) | ストア掲載文の草案（そのまま使える形） |
| [PRIVACY_POLICY_DRAFT.md](PRIVACY_POLICY_DRAFT.md) | プライバシーポリシー草案。公開版は `site/privacy-ja.html` |

## 仕様

| 文書 | 中身 |
|---|---|
| [dog_health_app_spec.md](dog_health_app_spec.md) | 機能仕様書（v0.2）。番号（6.4、8.2 など）はコード中のコメントから参照されている |

---

# 📦 完了済みの記録 → [`archive/`](archive/)

読まなくても作業は進みます。**「これは終わったのか？」を確かめたいときだけ**開いてください。
各ファイルの冒頭に、何が終わったのかを1行で書いてあります。

| 文書 | 済んだこと |
|---|---|
| [archive/STATUS.md](archive/STATUS.md) | 2026-08-14 時点の作業状況スナップショット |
| [archive/NEXT_SESSION.md](archive/NEXT_SESSION.md) | 2026-08-16 時点の次回作業メモ |
| [archive/PLAN_ads.md](archive/PLAN_ads.md) | 広告の実装（本文の「未着手」は当時のまま） |
| [archive/PLAN_referral_reward.md](archive/PLAN_referral_reward.md) | 紹介者特典・保留付与・セッション期限の実装 |
| [archive/PLAN_fixes_round2.md](archive/PLAN_fixes_round2.md) | 実機テスト第1回の指摘対応 |
| [archive/PLAN_implementation_first.md](archive/PLAN_implementation_first.md) | 「実装を先に」への方針転換（実装は完了） |
| [archive/PRIVACY_POLICY_AUDIT_20260818.md](archive/PRIVACY_POLICY_AUDIT_20260818.md) | ポリシーと実装の照合（指摘は反映済み） |
| [archive/VERIFICATION_CHECKLIST_R4.md](archive/VERIFICATION_CHECKLIST_R4.md) | 第4回の差分確認 |
| [archive/VERIFICATION_CHECKLIST_R5.md](archive/VERIFICATION_CHECKLIST_R5.md) | 第5回の差分確認 |
| [archive/ANNOUNCEMENT_TEST_DATA.md](archive/ANNOUNCEMENT_TEST_DATA.md) | お知らせ機能の実機確認 |
| [archive/CLOUD_ACCOUNT_SETUP.md](archive/CLOUD_ACCOUNT_SETUP.md) | クラウド各社のアカウント発行 |
| [archive/CLOUD_SETUP_CHECKLIST.md](archive/CLOUD_SETUP_CHECKLIST.md) | 実環境の整備 |
| [archive/CLOUD_PHASE_TASKS.md](archive/CLOUD_PHASE_TASKS.md) | クラウド設定フェーズでしかできない作業 |
| [archive/FIREBASE_SETUP_GUIDE.md](archive/FIREBASE_SETUP_GUIDE.md) | Firebase の構築（再構築時のみ参照） |
| [archive/SETUP_STEPS_ANTHROPIC_CLOUDFLARE.md](archive/SETUP_STEPS_ANTHROPIC_CLOUDFLARE.md) | Anthropic / Cloudflare の設定（同上） |
| [archive/RECRUITMENT_9_1_PLAN.md](archive/RECRUITMENT_9_1_PLAN.md) | テスター募集の初版（TESTER_RECRUITMENT.md に作り直し） |

---

# この整理について（2026-08-22）

**`C:\Dev\docs` は廃止しました。** 同じ名前の文書が2箇所にあり、どちらが正か
分からない状態でした。中身を比べたところ、**SESSION_HANDOVER.md 以外はすべて
このフォルダ側が新しい**（または同一）だったので、新しかった
SESSION_HANDOVER.md だけをここへ移し、旧フォルダは
`C:\Dev\docs_superseded_20260822` へ退避しました（消していません）。

**以降、文書はこのフォルダ（`wanote/docs/`）だけです。** Git で管理されるので、
いつ何が変わったかも追えます。
