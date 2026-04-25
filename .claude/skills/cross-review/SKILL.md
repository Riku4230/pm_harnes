---
name: cross-review
description: Cross-Model Review。Codex CLIまたはClaude subagentで成果物の独立レビュー。
when_to_use: 「レビューして」「Codexに見てもらって」「セカンドオピニオン」
---

# cross-review

## Required Context
- workspace/ の最新成果物（レビュー対象）

## 前提条件
- Codex CLI（`npm install -g @openai/codex`）がインストール済み
- `codex login` で認証済み

## フォールバック
Codex CLIが利用できない場合:
- Claude subagent（Agent tool）で独立レビューを実行
- メインコンテキストとは分離された視点でレビュー

## ワークフロー

### Step 1: 成果物特定
workspace/ の最新ファイル、またはユーザーが指定したファイルを特定。

### Step 2: レビュー実行
Codex利用可能 → codex execでレビュー依頼
Codex不可 → Agent toolでsubagent起動

レビュー観点:
- 網羅性（抜け漏れがないか）
- 整合性（docs/state/との矛盾がないか）
- 盲点（作成者が見落としている点）
- 受け手視点（この情報で相手は判断できるか）

### Step 3: 結果提示
レビュー結果をユーザーに提示。修正はユーザー承認後。

## 使い分け
- risk-check後 → recommended（リスクの見落としは致命的）
- draft-update後 → recommended（外部向けは品質重要）
- meeting-import後 → optional
- wbs-update後 → not needed（Computational FBで十分）
