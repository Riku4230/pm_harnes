---
name: source-sync
description: Fetch latest info from Slack/Notion/sources into daily digest. Schedulable.
when_to_use: 「情報取ってきて」「Slack同期」「Notion同期」「ソース同期」「最新情報」「情報集めて」「Slack確認して」「今日の状況まとめて」「コンテキスト更新」
allowed-tools: Read, Write, Bash, mcp__*
permission_mode: edit
---

# source-sync

Notion/Slack/その他の情報ソースから最新情報を取得し、**1日1ファイル**にまとめてsources/に蓄積する。
取得した情報からプロジェクトへの影響を検出し、state/の更新を提案する。

## Required Context
- state/SOURCES.json（情報ソースの定義）
- state/STATUS.json

## Token Budget
〜5,000トークン

## ワークフロー

### Step 1: ソース定義の確認

state/SOURCES.jsonを読む。

ソースが未登録の場合:
「情報ソースを追加しますか？」と案内:
- Slack: チャンネル名とチャンネルIDを入力
- Notion: ページ名とページIDを入力
- その他: 名前とアクセス方法を入力

### Step 2: 情報取得

各ソースからMCPを使って最新情報を取得:

**Slack（mcp__slack__*）:**
- 指定チャンネルの直近メッセージを取得
- スレッドの重要な議論も含む

**Notion（mcp__notionApi__*）:**
- 指定ページの最新コンテンツを取得
- 変更があれば取得

**MCP未接続の場合:**
- 「{type} MCPが接続されていません」と案内
- 接続済みのソースだけ処理続行

### Step 3: 1日1ファイルにまとめて蓄積

sources/YYYY-MM-DD.md として保存。全ソースを1ファイル内に見出しで整理。
既に同日のファイルが存在する場合は追記。

### Step 4: コンテキスト更新提案

取得した情報からプロジェクトに影響がある内容を検出:
- 新しい決定事項 → CHANGELOG.jsonに追記すべきか提案
- 新しいリスク → RISK.jsonに追記すべきか提案
- タスク変更 → WBS.jsonの更新を提案
- ステークホルダー情報変更 → STAKEHOLDER.mdの更新を提案

全て**提案のみ**。実際の更新はユーザー承認後。
承認された場合はstate/STATUS.json（next_actions, blockers, context_notes）も更新。

### /schedule対応
```
/schedule で「毎日 9:00にsource-syncを実行」が可能。
自動実行時: 成果物をcommit + push。次回session-start時に差分表示。
```
