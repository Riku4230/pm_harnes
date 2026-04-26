---
name: setup
description: Full project setup. Hearing, file generation, git, schedules.
when_to_use: 「セットアップして」「setup」「プロジェクト始めたい」「初期設定」
---

# setup

PM-Harnessの初回セットアップ。AskUserQuestionでヒアリングし、ファイルを動的に生成する。

## 前提

pm-harnesリポジトリをフォルダにコピー済みで、.claude/が存在すること。

## ワークフロー

### Step 1: プロジェクトヒアリング

**AskUserQuestionを使って1問ずつ聞く。まとめて聞かない。**

質問1: プロジェクト名
```
AskUserQuestion:
  question: "プロジェクト名を教えてください。（例: 新商品ブランディング、業務プロセス改善、引越し）"
  header: "Project"
  options: なし（自由入力のみ）
```

質問2: ゴール
```
AskUserQuestion:
  question: "このプロジェクトのゴールは何ですか？何を達成したら成功ですか？"
  header: "Goal"
  options: なし（自由入力のみ）
```

質問3: 期限
```
AskUserQuestion:
  question: "期限はありますか？"
  header: "Deadline"
  options:
    - label: "期限あり"
      description: "次の質問で具体的な日付を入力"
    - label: "特になし"
      description: "期限なしで進める"
```
期限ありの場合、追加で日付を聞く。

質問4: 関係者
```
AskUserQuestion:
  question: "このプロジェクトに関わる人は？"
  header: "Members"
  options:
    - label: "自分だけ"
      description: "個人プロジェクト"
    - label: "チームメンバーがいる"
      description: "社内のチームで進める"
    - label: "クライアントがいる"
      description: "外部のステークホルダーがいる"
```

質問5: プロジェクトの性質
```
AskUserQuestion:
  question: "どんなプロジェクトですか？"
  header: "Type"
  options:
    - label: "日常・個人タスク"
      description: "引越し、学習、個人目標など"
    - label: "コンサル・ビジネス"
      description: "BPR、導入支援、ブランディングなど"
    - label: "システム開発"
      description: "アプリ開発、インフラ構築など"
```

### Step 2: 必要ファイルの判定

ヒアリング結果から生成するファイルを判定し、AskUserQuestionで確認:

```
AskUserQuestion:
  question: "以下のファイルを生成します。変更はありますか？"
  header: "Files"
  options:
    - label: "この内容でOK"
      description: "{生成ファイル一覧を表示}"
    - label: "追加したい"
      description: "他に必要なファイルがあれば教えてください"
    - label: "減らしたい"
      description: "不要なファイルがあれば教えてください"
```

#### 判定ロジック

| 条件 | 生成するファイル |
|---|---|
| 全プロジェクト共通 | STATUS.json, CHANGELOG.json, IMPROVEMENTS.json, SESSION_LOG.json, ALERTS.json, REVIEW_PROPOSALS.json, PROJECT.md |
| チームメンバー or クライアント | + STAKEHOLDER.md, COMMUNICATION.md |
| 期限あり or コンサル or 開発 | + WBS.json, RISK.json |
| システム開発 | + SPEC.md, BACKLOG.json |

### Step 3: ファイル生成

確認済みのファイルをtemplates/から生成。ディレクトリも作成:
- docs/, state/, meeting/, workspace/, sources/

### Step 4: 初期コンテキスト投入

ヒアリング内容を各ファイルに記入:
- state/STATUS.json: project_name, current_phase, next_actions
- docs/PROJECT.md: ゴール、スコープ、期限
- docs/STAKEHOLDER.md: 関係者（該当時）
- state/WBS.json: 初期タスク（期限から逆算、3-5個）
- state/RISK.json: 初期リスク（懸念点があれば）
- CLAUDE.md: project_nameを記入

### Step 5: Git初期化 + GitHub連携

```
AskUserQuestion:
  question: "GitHubリポジトリを作成しますか？定期レポートの自動実行に必要です。"
  header: "GitHub"
  options:
    - label: "作成する（推奨）"
      description: "プライベートリポジトリを作成してpush"
    - label: "スキップ"
      description: "後から設定可能。scheduleは使えません"
```

git init → .gitignore生成 → 初回コミット → （GitHub選択時）gh repo create + push

### Step 6: Schedule設定

**前提: GitHub連携済み。**

```
AskUserQuestion:
  question: "定期実行するタスクを選んでください。"
  header: "Schedule"
  multiSelect: true
  options:
    - label: "source-sync（毎日9:00）"
      description: "Slack/Notionから情報を自動取得"
    - label: "weekly-report（毎週金曜16:00）"
      description: "週次レポートを自動生成"
    - label: "retro（毎週金曜17:00）"
      description: "振り返りレポートを自動生成"
```

選択されたものだけ `/schedule` で設定。

### Step 7: 情報ソース設定

```
AskUserQuestion:
  question: "Slack/Notionなど、プロジェクト情報がある場所はありますか？"
  header: "Sources"
  options:
    - label: "Slackチャンネルがある"
      description: "チャンネル名とIDを入力"
    - label: "Notionページがある"
      description: "ページ名とIDを入力"
    - label: "今はない"
      description: "後からsource-syncで追加可能"
```

選択に応じてSOURCES.jsonに追加。

### Step 8: 完了

セットアップ結果をsystemMessageで表示し、次のアクションを案内。
