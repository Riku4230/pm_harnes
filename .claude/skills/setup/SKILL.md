---
name: setup
description: Full project setup. Hearing, file generation, git, schedules.
when_to_use: 「セットアップして」「setup」「プロジェクト始めたい」「初期設定」
---

# setup

PM-Harnessの初回セットアップ。AskUserQuestionでまとめてヒアリングし、ファイルを動的に生成する。

## 前提

pm-harnesリポジトリをフォルダにコピー済みで、.claude/が存在すること。

## ワークフロー

### Step 1: プロジェクトヒアリング

**AskUserQuestionで3問を1回でまとめて聞く。プロジェクトの性質はゴールと関係者から推測する。**

```
AskUserQuestion:
  questions:
    - question: "プロジェクト名とゴールを教えてください（例: 引越し — 5月末までに新居に移る）"
      header: "Project"
      options:
        - label: "(自由入力)"
          description: "プロジェクト名 — ゴール の形式で入力"

    - question: "期限はありますか？"
      header: "Deadline"
      options:
        - label: "期限あり"
          description: "日付を備考欄に入力（例: 2026-06-30）"
        - label: "特になし"
          description: "期限なし"

    - question: "関わる人は？"
      header: "Members"
      options:
        - label: "自分だけ"
          description: "個人プロジェクト"
        - label: "チームメンバーがいる"
          description: "社内メンバーで進める"
        - label: "クライアントがいる"
          description: "外部ステークホルダーあり"
```

プロジェクトの性質（日常/コンサル/開発）はゴールと関係者の回答から自動推測する。

### Step 3: 既存ファイルにヒアリング内容を書き込み

**テンプレートからのコピーやディレクトリ作成は不要。**
pm_harnesをフォルダコピーした時点でstate/docs/meeting/workspace/sources/は全て存在する。
setupがやるのはヒアリング内容を既存ファイルに書き込むことだけ。

書き込み先:
- state/STATUS.json → project_name, current_phase, next_actions, last_updated を記入
- docs/PROJECT.md → ゴール、スコープ、期限を記入
- CLAUDE.md → project_name, project_typeを記入

関係者がいる場合（チーム or クライアント選択時）:
- docs/STAKEHOLDER.md → 関係者情報を記入

期限がある場合:
- state/WBS.json → 期限から逆算して初期タスク3-5個を生成

### Step 5: Git + GitHub

```
AskUserQuestion:
  question: "GitHubリポジトリを作成しますか？定期レポートの自動実行に必要です。"
  header: "GitHub"
  options:
    - label: "作成する（推奨）"
      description: "プライベートリポジトリを作成"
    - label: "スキップ"
      description: "後から設定可能"
```

git init → .gitignore → commit → （GitHub選択時）gh repo create + push

### Step 6: Schedule設定（RemoteTrigger）

**前提: Step 5でGitHub連携済みであること。**

まずAskUserQuestionで選択:
```
AskUserQuestion:
  questions:
    - question: "定期実行するタスクを選んでください"
      header: "Schedule"
      multiSelect: true
      options:
        - label: "source-sync（毎日9:00）"
          description: "Slack/Notionから情報自動取得"
        - label: "weekly-report（毎週金曜16:00）"
          description: "週次レポート自動生成"
        - label: "retro（毎週金曜17:00）"
          description: "振り返りレポート自動生成"

    - question: "プロジェクト情報があるツールは？"
      header: "Sources"
      multiSelect: true
      options:
        - label: "Slack"
          description: "チャンネルIDを後で入力"
        - label: "Notion"
          description: "ページIDを後で入力"
        - label: "今はない"
          description: "後から追加可能"
```

選択されたscheduleをRemoteTrigger(create)で登録する。
GitHubリポジトリURLはgit remote get-url originで取得。

**source-sync（毎日9:00 JST = 0:00 UTC）:**
```
RemoteTrigger(create):
  body:
    name: "pm-harness: source-sync"
    cron_expression: "0 0 * * *"
    job_config:
      ccr:
        session_context:
          allowed_tools: ["Bash","Read","Write","Edit","Glob","Grep"]
          model: "claude-sonnet-4-6"
          sources:
            - git_repository:
                url: "{github_url}"
                allow_unrestricted_git_push: true
        events:
          - type: "user"
            data:
              message:
                role: "user"
                content: "/source-sync を実行してください。完了後 git add sources/ state/ && git commit -m 'source-sync: {date}' && git push origin main"
```

**weekly-report（毎週金曜16:00 JST = 7:00 UTC）:**
```
RemoteTrigger(create):
  body:
    name: "pm-harness: weekly-report"
    cron_expression: "0 7 * * 5"
    job_config: （同様の構造、promptはweekly-reportスキル実行+commit+push）
```

**retro（毎週金曜17:00 JST = 8:00 UTC）:**
```
RemoteTrigger(create):
  body:
    name: "pm-harness: retro"
    cron_expression: "0 8 * * 5"
    job_config: （同様の構造、promptはretroスキル実行（Phase1-2のみ）+commit+push）
```

ソースのIDは選択後に個別に聞き、state/SOURCES.jsonに追加。

### Step 7: 完了

セットアップ結果を表示し、最初のタスクを案内。
