---
name: wbs-update
description: Update WBS progress, check milestones and dependencies.
when_to_use: 「WBS更新して」「進捗更新」「スケジュール確認」
permission_mode: edit
---

# wbs-update

## Required Context
- state/WBS.json
- state/STATUS.json

## Token Budget
〜4,000トークン

## ワークフロー

### Step 1: 現状確認
WBS.jsonとSTATUS.jsonを読み込み、現在の進捗を把握。

### Step 2: 進捗反映
ユーザーからの情報を基にタスクのstatus/進捗率を更新。

### Step 3: マイルストーン確認
マイルストーンまでの残タスク数、残日数を計算。

### FB-Computational
- [Block] 依存関係の循環検出（A→B→C→Aのようなループ）
- [Warn] 期限超過タスク（due < today && status != done）
- [Warn] 日付不整合（start_date > end_date）

### Post
- state/WBS.json更新
- state/STATUS.json更新（current_phase, next_actions）
