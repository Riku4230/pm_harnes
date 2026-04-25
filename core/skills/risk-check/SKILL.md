---
name: risk-check
description: リスクの再評価、新規リスク検出、対応策の確認。
when_to_use: 「リスクチェックして」「リスク確認」「リスク評価」
---

# risk-check

## Required Context
- state/RISK.json
- state/WBS.json（スケジュールリスク用）

## Token Budget
〜3,000トークン

## ワークフロー

### Step 1: 既存リスクの再評価
RISK.jsonの各リスクについて:
- impact/probabilityの妥当性を確認
- mitigation（対応策）の進捗確認
- 新しい情報で評価が変わるものがないか

### Step 2: 新規リスクの検出
WBS.jsonのスケジュール状況やSTATUS.jsonの状態から:
- スケジュールリスク
- リソースリスク
- 外部依存リスク

### Step 3: 対応策の確認
各リスクにmitigation（対応策）が定義されているか確認。

### FB-Computational
- [Block] 高リスク（impact=high）の対応策未定義 → スキーマで構造的に防止
- [Warn] リスク件数の急増（前回比）
- [Warn] 30日以上未更新のリスク

### Post
- state/RISK.json更新
