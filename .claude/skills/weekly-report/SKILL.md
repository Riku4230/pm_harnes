---
name: weekly-report
description: Weekly report. Aggregate progress/decisions/risks. Schedulable.
when_to_use: 「週報作って」「今週のまとめ」「ウィークリーレポート」「定例資料」
allowed-tools: Read, Write
permission_mode: edit---

# weekly-report

## Required Context
- state/STATUS.json
- state/WBS.json
- state/CHANGELOG.json
- state/RISK.json
- state/ALERTS.json

## Token Budget
〜5,000トークン

## Permission Mode
**readonly** — レポート生成のみ。workspace/に保存。送信は人間が行う。

## ワークフロー

### Step 1: 期間特定
対象期間を確認（デフォルト: 直近7日間）。

### Step 2: 進捗集約
WBS.jsonから:
- 今週完了したタスク
- 進行中のタスク
- 新たにブロックされたタスク
- マイルストーンまでの残り

### Step 3: 意思決定集約
CHANGELOG.jsonから今週のエントリ:
- 決定事項
- ステークホルダー共有履歴
- スコープ変更

### Step 4: リスク状況
RISK.jsonから:
- 新規リスク
- 解決したリスク
- 対応策の進捗
- 高リスクの状況

### Step 5: アラート集約
ALERTS.jsonから:
- 未解決のrule_alerts
- 未解決のllm_alerts

### Step 6: レポート生成
workspace/weekly-report-{date}.mdに生成:

```markdown
# Weekly Report: {期間}

## 進捗サマリー
完了: X件 / 進行中: Y件 / ブロック: Z件
マイルストーン「{name}」まであとN日（残タスクM件）

## 今週の意思決定
| 日付 | 決定事項 | 影響 |

## リスク状況
| リスク | 影響度 | 対応策 | ステータス |

## アラート（未解決）
- ...

## 来週の予定
- ...
```

### /schedule対応
```
/schedule で「毎週金曜 16:00にweekly-reportを実行」が可能。
生成されたレポートはworkspace/に保存。
PMが確認・編集後にステークホルダーへ共有。
```
