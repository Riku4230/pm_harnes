---
name: setup
description: Git/GitHub init, configure schedules. Run after copying pm-harness.
when_to_use: 「セットアップして」「setup」「初期設定」
---

# setup

PM-Harnessフォルダをコピーした後の初回セットアップ。
前提: pm-harnesリポジトリをフォルダにコピー済みで、.claude/が既に存在する。

## 前提確認

まず以下を確認:
- .claude/rules/ が存在するか
- .claude/hooks/ が存在するか
- .claude/skills/ が存在するか
- .claude/settings.json が存在するか

存在しない場合: 「pm-harnesリポジトリをこのフォルダにコピーしてください」と案内。

## ワークフロー

### Step 1: プロジェクトタイプ確認

タイプだけ確認（詳細ヒアリングはproject-initで行う）:
- **personal** — 日常・個人タスク（最小構成）
- **consulting** — コンサル・BPR・導入支援（フル構成）
- **system_dev** — システム開発（フル + SPEC + BACKLOG）

タイプに応じてstate/とdocs/の初期ファイルを生成:

**personal**:
```bash
mkdir -p state docs meeting workspace
# templates/personal/ から必要なファイルをコピー
```

**consulting**:
```bash
mkdir -p state docs meeting workspace
# templates/consulting/ から全ファイルをコピー
```

**system_dev**:
```bash
mkdir -p state docs meeting workspace
# templates/system_dev/ から全ファイルをコピー
```

CLAUDE.mdにproject_typeを記入。

### Step 2: Git初期化

```bash
# 既にgitリポジトリでなければ初期化
git init

# .gitignore生成（なければ）
echo "state/*.count" >> .gitignore
echo "node_modules/" >> .gitignore
```

### Step 3: GitHub連携

scheduleの実行にGitHubリモートが必要。先に設定する。

```bash
gh auth status  # 認証確認
```

ユーザーに確認:
- 「GitHubリポジトリを作成しますか？scheduleの自動実行に必要です。」
- A) 作成する（推奨）→ `gh repo create {project_name} --private --source=. --push`
- B) スキップ → scheduleは後で設定可能と案内

### Step 4: 初回コミット

```bash
git add -A
git commit -m "PM-Harness: initial setup ({project_type})"
git push  # GitHub連携済みの場合
```

### Step 5: Schedule設定

**前提: GitHubリモートが設定済みであること。**

以下のscheduleをユーザーに提案:

| スケジュール | 内容 | 推奨 |
|---|---|---|
| **weekly-report** | 週次レポート生成 | 毎週金曜 16:00 |
| **retro** | 振り返り | 毎週金曜 17:00 |

Claude Codeの `/schedule` で設定。

### Step 6: 完了 → project-init案内

```
PM-Harnessセットアップ完了！

✅ プロジェクトタイプ: {type}
✅ Git: 初期化済み
✅ GitHub: {連携済み / スキップ}
✅ ファイル配置: state/ docs/ meeting/ workspace/
✅ Schedule: {設定内容 / スキップ}
✅ Hooks: .claude/settings.json で設定済み
   - SessionStart: プロジェクト状況の自動表示
   - SessionEnd: L1ルールFB自動実行 + L2/L3判定
   - PreToolUse: docs/state/変更ログ
   - PostToolUse: JSONスキーマバリデーション

次のステップ:
  → 「プロジェクト始めたい」と言ってproject-initを実行してください。
  プロジェクトの詳細をヒアリングし、docs/state/を充実させます。
```
