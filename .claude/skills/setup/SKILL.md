---
name: setup
description: Install harness, git/GitHub init, configure schedules.
when_to_use: 「セットアップして」「setup」「初期設定」「ハーネス導入」
---

# setup

PM-Harnessの環境セットアップ。ファイル配置→Git/GitHub→Schedule設定の順で実行。
プロジェクト内容のヒアリングはこのスキルでは行わない（project-initで行う）。

## ワークフロー

### Step 1: プロジェクトタイプ確認

タイプだけ確認する（詳細ヒアリングはproject-initで行う）:
- **personal** — 日常・個人タスク（最小構成）
- **consulting** — コンサル・BPR・導入支援（フル構成）
- **system_dev** — システム開発（フル + SPEC + BACKLOG）

### Step 2: Git初期化

```bash
# gitリポジトリでなければ初期化
git init
```

.gitignore を生成:
```
state/*.count
node_modules/
```

### Step 3: GitHub連携

ユーザーに確認してから実行。scheduleの実行にGitHubリモートが必要なため、先に設定する。

```bash
# gh CLIが使えるか確認
gh auth status

# ユーザーが希望する場合
gh repo create {project_name} --private --source=. --push
```

GitHubなしでもPM-Harness自体は動作する。ただしschedule（Step 5）は使えない旨を伝える。

### Step 4: ファイル配置

PM-Harnessのcore/からプロジェクトにファイルを配置。

```bash
bash install.sh --target . --type {project_type}
```

配置後の確認:
- .claude/rules/ に3ファイルあるか
- .claude/hooks/ にスクリプトがあるか
- .claude/skills/ にスキルがあるか
- .claude/settings.json が存在するか
- state/ に初期JSONがあるか
- docs/ にテンプレートがあるか

初回コミット:
```bash
git add -A
git commit -m "PM-Harness: initial setup ({project_type})"
git push  # GitHub連携済みの場合
```

### Step 5: Schedule設定

**前提: GitHubリモートが設定済みであること。**
未設定の場合はスキップし、後から設定可能と案内する。

以下のscheduleをユーザーに提案。承認されたものだけ設定:

| スケジュール | 内容 | 推奨タイミング |
|---|---|---|
| **weekly-report** | 週次レポート生成 | 毎週金曜 16:00 |
| **retro** | 振り返り | 毎週金曜 17:00 or 隔週 |

設定方法: Claude Codeの `/schedule` コマンドを使用。

### Step 6: 完了 → project-init案内

```
PM-Harnessセットアップ完了！

✅ Git: {初期化済み / 既存}
✅ GitHub: {連携済み / スキップ}
✅ ファイル配置: rules/hooks/skills/state/docs ({project_type})
✅ Schedule: {設定内容 / スキップ（GitHub未連携のため）}

次のステップ:
  → project-init を実行してプロジェクト情報を入力してください。
  「プロジェクト始めたい」と言えばOKです。
```
