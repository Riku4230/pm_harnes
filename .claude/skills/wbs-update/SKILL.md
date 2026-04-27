---
name: wbs-update
description: Update WBS progress, check milestones and dependencies.
when_to_use: 「WBS更新して」「進捗更新」「スケジュール確認」「タスク更新」「ステータス変更」
permission_mode: edit
---

# wbs-update

## Required Context
- state/WBS.json
- state/STATUS.json

## Token Budget
〜4,000トークン

## ルーティング判定

ユーザーの意図に応じて適切なスキルにルーティングする:
- **進捗・ステータス更新** → このスキル(wbs-update)で対応
- **タスクの精緻化・分解・詳細化** → `/decompose` スキルに委譲

判定キーワード:
- decompose行き: 「精緻に」「細かく」「分解」「サブタスク」「詳細化」「見直し」「粒度」「ブレイクダウン」
- wbs-update続行: 「進捗」「ステータス」「完了」「着手」「ブロック」「スケジュール確認」

## ワークフロー

### Step 1: 現状確認
WBS.jsonとSTATUS.jsonを読み込み、現在の進捗を把握。

### Step 2: 進捗反映
ユーザーからの情報を基にタスクのstatus/進捗率を更新。

### Step 3: マイルストーン確認
マイルストーンまでの残タスク数、残日数を計算。

### Step 4: WBS.json + STATUS.json更新

WBS.json, STATUS.json（current_phase, next_actions）を更新。
**循環検出・期日整合性・スケジュール競合・STATUS整合性チェックはPostToolUse hook (validate-state.sh) が自動実行する。スキル内で独自チェックしないこと。**
hookからエラーやImpact Analysisが返った場合はその指摘に従って修正する。
