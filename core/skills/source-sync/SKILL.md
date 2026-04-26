---
name: source-sync
description: Fetch latest info from Slack/Notion/sources. Auto-schedulable.
when_to_use: 「情報取ってきて」「Slack同期」「Notion同期」「ソース同期」「最新情報」
allowed-tools: Read, Write, Bash, mcp__*
persona: personas/analyst.md
policy: policies/quality-policy.md
permission_mode: edit
---

# source-sync

Notion/Slack/その他の情報ソースから最新情報を取得し、sources/にmdファイルとして蓄積する。
/scheduleで毎日自動実行可能。

## Required Context
- state/SOURCES.json（情報ソースの定義）

## Token Budget
〜5,000トークン

## フォルダ構成

```
sources/                          ← 情報ソースから取得した情報の蓄積
├── slack/
│   ├── 2026-04-25_general.md        チャンネルごと・日付ごと
│   ├── 2026-04-25_project-x.md
│   └── 2026-04-26_general.md
├── notion/
│   ├── 2026-04-25_要件定義書.md      ページごと・日付ごと
│   └── 2026-04-25_議事録DB.md
└── other/
    └── 2026-04-25_メール要約.md
```

## ワークフロー

### Step 1: ソース定義の確認

state/SOURCES.jsonを読む。

ソースが未登録の場合:
「情報ソースを追加しますか？」と案内:
- Slack: チャンネル名とチャンネルIDを入力
- Notion: ページ名とページIDを入力
- その他: 名前とアクセス方法を入力

ソース追加例:
```json
{
  "sources": [
    {
      "type": "slack",
      "name": "プロジェクトX",
      "id": "C0123456789",
      "description": "プロジェクトXの主要チャンネル",
      "added": "2026-04-25"
    },
    {
      "type": "notion",
      "name": "要件定義書",
      "id": "abc123def456",
      "description": "最新の要件定義書ページ",
      "added": "2026-04-25"
    }
  ]
}
```

### Step 2: 情報取得

各ソースからMCPを使って最新情報を取得:

**Slack（mcp__slack__*）:**
- 指定チャンネルの直近メッセージを取得
- 日付でフィルタ（前回取得以降のメッセージ）
- スレッドの重要な議論も含む

**Notion（mcp__notionApi__*）:**
- 指定ページの最新コンテンツを取得
- 最終更新日を確認し、変更があれば取得

**MCP未接続の場合:**
- 「{type} MCPが接続されていません。接続後に再実行してください」と案内
- 接続済みのソースだけ処理を続行

### Step 3: 蓄積

取得した情報をsources/{type}/YYYY-MM-DD_{name}.mdとして保存:

```markdown
# {source_name} — {date}

## 取得元
- Type: {slack|notion|other}
- ID: {id}
- 取得日時: {timestamp}

## 内容
{取得したコンテンツ}

## 要点
- {重要なポイントを3-5行で要約}

## プロジェクトへの影響
- {state/STATUS.jsonやRISK.jsonに反映すべき情報があればここに}
```

### Step 4: コンテキスト更新提案

取得した情報からプロジェクトに影響がある内容を検出:
- 新しい決定事項 → CHANGELOG.jsonに追記すべきか提案
- 新しいリスク → RISK.jsonに追記すべきか提案
- タスク変更 → WBS.jsonの更新を提案
- ステークホルダー情報変更 → STAKEHOLDER.mdの更新を提案

全て**提案のみ**。実際の更新はユーザー承認後。

### Step 5: 完了サマリー

```
source-sync完了:
  Slack #project-x: 15件の新メッセージ → sources/slack/2026-04-25_project-x.md
  Notion 要件定義書: 更新あり → sources/notion/2026-04-25_要件定義書.md

コンテキスト更新提案:
  - [提案] CHANGELOG: 「API仕様変更が決定」を追記
  - [提案] RISK: 「ベンダー側の遅延リスク」を追加
  適用しますか？
```

### ソース追加スキル

ユーザーが「Slackチャンネル追加して」「Notionページ追加して」と言った場合:
1. type/name/idを聞く
2. state/SOURCES.jsonに追記
3. 即座にそのソースから初回取得を実行

### /schedule対応

```
/schedule で「毎日 9:00にsource-syncを実行」が可能。
自動実行時:
  - SOURCES.jsonに登録された全ソースから取得
  - sources/に蓄積
  - コンテキスト更新提案はstate/ALERTS.jsonに記録
  - 次回session-start時に「N件の新情報、N件の更新提案」として表示
```

### 古いsources/の管理

sources/配下のファイルは蓄積型。30日以上前のファイルは自動削除しない。
容量が気になる場合はユーザーが手動で削除するか、retroで整理を提案。
