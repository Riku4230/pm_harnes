---
name: context-pack
description: Slack/Notion/各種ソースからプロジェクト情報を収集・整理する。日報に限定しない汎用情報収集。
when_to_use: 「情報集めて」「Slack確認して」「今日の状況まとめて」「コンテキスト更新」
allowed-tools: Read, Bash, mcp__*
persona: personas/analyst.md
policy: policies/quality-policy.md
permission_mode: edit
---

# context-pack

## Required Context
- state/STATUS.json
- docs/COMMUNICATION.md（報告ルールがある場合）

## Token Budget
〜3,000トークン

## ワークフロー

### Step 1: ソース確認
利用可能な情報ソースを確認:
- Slack MCP（接続されている場合）
- Notion MCP（接続されている場合）
- meeting/ 配下の新しい議事録
- その他ユーザーが指定するソース

### Step 2: 情報収集
各ソースから関連情報を収集。鮮度チェック:
- いつの情報か
- 現在も有効か
- 既にstate/に記録済みでないか

### Step 3: 整理・記録
収集した情報をstate/STATUS.jsonに反映:
- current_phase の更新
- next_actions の更新
- blockers の更新
- context_notes の更新

重要な決定事項があればstate/CHANGELOG.jsonに追記。

### FB-Computational
- [Warn] 取得ソース数が想定より少ない場合に警告
