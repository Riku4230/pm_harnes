---
name: setup
description: Full project setup. Hearing, git, GitHub, schedules, initial docs.
when_to_use: 「セットアップして」「setup」「プロジェクト始めたい」「初期設定」
---

# setup

PM-Harnessの初回セットアップ。ヒアリングからSchedule設定まで一括で行う。

## 前提

pm-harnesリポジトリをフォルダにコピー済みで、.claude/が存在すること。

## ワークフロー

### Step 1: プロジェクトヒアリング

以下をユーザーに確認:
- **プロジェクト名** — 何のプロジェクトか
- **ゴール** — 何を達成したいか
- **関係者** — 誰が関わるか（1人ならpersonal候補）
- **期限** — いつまでか（あれば）
- **概要** — どんな内容か（コンサル？開発？個人タスク？）

### Step 2: タイプ自動判定

ヒアリング内容からプロジェクトタイプを判定し、ユーザーに確認:

| タイプ | 判定基準 |
|---|---|
| **personal** | 関係者が自分だけ、日常タスク、個人の目標 |
| **consulting** | クライアントがいる、BPR/導入支援、複数ステークホルダー |
| **system_dev** | システム開発、コーディングあり、技術仕様が必要 |

「{タイプ}で設定しますがよいですか？」と確認。

### Step 3: Git初期化 + GitHub連携

```bash
git init  # 既にgitリポジトリでなければ
```

.gitignore生成:
```
state/*.count
node_modules/
```

GitHub連携:
- 「GitHubリポジトリを作成しますか？定期レポートの自動実行に必要です。」
- A) 作成する → `gh repo create {project_name} --private --source=. --push`
- B) スキップ → scheduleは後で設定可能と案内

### Step 4: ファイル生成

タイプに応じてstate/とdocs/の初期ファイルを生成:

**personal**: state/STATUS.json + docs/PROJECT.md
**consulting**: 全state/(7ファイル) + 全docs/(3ファイル)
**system_dev**: consulting全部 + docs/SPEC.md + state/BACKLOG.json

共通: meeting/ + workspace/ ディレクトリ作成
CLAUDE.mdにproject_name, project_typeを記入。

### Step 5: 初期コンテキスト投入

Step 1のヒアリング内容をファイルに記入:
- state/STATUS.json: project_name, project_type, current_phase, next_actions
- docs/PROJECT.md: ゴール、スコープ、期限
- docs/STAKEHOLDER.md: 関係者情報（consulting/system_devのみ）
- state/WBS.json: 初期マイルストーン（期限があれば逆算してタスク生成）

### Step 6: 初回コミット

```bash
git add -A
git commit -m "PM-Harness: project setup ({project_type})"
git push  # GitHub連携済みの場合
```

### Step 7: Schedule設定

**前提: GitHubリモートが設定済みであること。**

以下のscheduleをユーザーに提案:

| スケジュール | 内容 | 推奨 |
|---|---|---|
| **weekly-report** | 週次レポート生成 | 毎週金曜 16:00 |
| **retro** | 振り返り | 毎週金曜 17:00 |

Claude Codeの `/schedule` で設定。

### Step 8: 完了

```
PM-Harnessセットアップ完了！

✅ プロジェクト: {project_name}（{project_type}）
✅ Git/GitHub: {状況}
✅ ファイル: docs/ state/ meeting/ workspace/
✅ Schedule: {設定内容}
✅ Hooks: 自動で有効（セッション開始/終了/バリデーション/承認ゲート）

次のセッションから:
- 開始時にプロジェクト状況 + アラートが自動表示されます
- 終了時にL1ルールFBが自動実行されます

作業を始めるには:
- 「情報集めて」「WBS作って」「リスクチェック」など、やりたいことを話しかけてください。
```
