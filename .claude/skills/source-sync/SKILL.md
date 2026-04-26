---
name: source-sync
description: Fetch latest info from Slack/Notion/sources into daily digest. Schedulable.
when_to_use: 「情報取ってきて」「Slack同期」「Notion同期」「ソース同期」「最新情報」
allowed-tools: Read, Write, Bash, mcp__*
permission_mode: edit
---

# source-sync

Notion/Slack/その他の情報ソースから最新情報を取得し、**1日1ファイル**にまとめてsources/に蓄積する。

## Required Context
- state/SOURCES.json（情報ソースの定義）

## Token Budget
〜5,000トークン

## フォルダ構成

```
sources/                          ← 1日1ファイル
├── 2026-04-25.md                    全ソースを1ファイルにまとめる
├── 2026-04-26.md
└── ...
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

### Step 3: 1日1ファイルにまとめて蓄積

sources/YYYY-MM-DD.md として保存。全ソースを1ファイル内に見出しで整理:

```markdown
# Source Sync: 2026-04-25

## Slack

### #project-x
- 田中: API仕様の変更について確認したい
- 佐藤: 来週の定例で議論しましょう
- (スレッド) 鈴木: 変更の影響範囲を調査中

### #general
- 山田: 来週の全体定例は水曜に変更

## Notion

### 要件定義書
- 最終更新: 2026-04-25
- 変更点: セクション3「認証フロー」に新しい要件を追加
- 追加内容の要約: 二段階認証を必須化する方針

### 議事録DB
- 新しい議事録: 2026-04-24 定例会議
- 決定事項: スコープ縮小（管理画面は次フェーズに延期）

## プロジェクトへの影響
- [提案] CHANGELOG: 「API仕様変更の議論開始」を記録
- [提案] RISK: 「仕様変更によるスケジュール影響」を追加
- [提案] WBS: 「認証フロー設計」タスクの追加を検討
```

既に同日のファイルが存在する場合は追記（同日に複数回実行した場合）。

### Step 4: コンテキスト更新提案

取得した情報からプロジェクトに影響がある内容を検出:
- 新しい決定事項 → CHANGELOG.jsonに追記すべきか提案
- 新しいリスク → RISK.jsonに追記すべきか提案
- タスク変更 → WBS.jsonの更新を提案
- ステークホルダー情報変更 → STAKEHOLDER.mdの更新を提案

全て**提案のみ**。実際の更新はユーザー承認後。

### Step 5: 完了サマリー

```
source-sync完了（2026-04-25）:
  Slack: 2チャンネル、23件のメッセージ
  Notion: 2ページ、1件の更新
  → sources/2026-04-25.md に保存

コンテキスト更新提案:
  - [提案] CHANGELOG: 「API仕様変更の議論開始」を追記
  - [提案] RISK: 「仕様変更スケジュール影響」を追加
  適用しますか？
```

### ソース追加

ユーザーが「Slackチャンネル追加して」「Notionページ追加して」と言った場合:
1. type/name/idを聞く
2. state/SOURCES.jsonに追記
3. 即座にそのソースから初回取得を実行

### /schedule対応

```
/schedule で「毎日 9:00にsource-syncを実行」が可能。
自動実行時:
  - SOURCES.jsonに登録された全ソースから取得
  - sources/YYYY-MM-DD.mdに蓄積
  - コンテキスト更新提案はstate/ALERTS.jsonに記録
  - 成果物をcommit + push
  - 次回session-start時に差分表示
```

### Schedule実行時のcommit+push

schedule実行の最後に必ず:
```bash
git add sources/ state/ALERTS.json
git commit -m "source-sync: {date}"
git push origin main
```

### 古いsources/の管理

sources/配下のファイルは蓄積型。30日以上前のファイルは自動削除しない。
容量が気になる場合はユーザーが手動で削除するか、retroで整理を提案。
