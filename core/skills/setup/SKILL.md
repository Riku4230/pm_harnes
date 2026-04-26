---
name: setup
description: Full project setup. Install harness, git init, schedule, and initial context.
when_to_use: 「セットアップして」「プロジェクト始めたい」「setup」「初期設定」
---

# setup

PM-Harnessの初回セットアップを一括で行う。
install.sh実行、git初期化、schedule設定、初期コンテキスト投入までを1つのフローで完了する。

## ワークフロー

### Step 1: プロジェクト情報ヒアリング

以下をユーザーに確認:
- **プロジェクト名** — state/STATUS.jsonのproject_nameに設定
- **プロジェクトタイプ** — personal / consulting / system_dev
  - 判断基準: 個人タスク→personal、クライアント案件→consulting、システム構築→system_dev
- **ゴール** — docs/PROJECT.mdに記載
- **関係者**（consulting/system_devのみ）— docs/STAKEHOLDER.mdに記載
- **期限**（あれば）— state/WBS.jsonの初期マイルストーンに設定

### Step 2: ファイル配置

PM-Harnessのcore/からプロジェクトにファイルを配置する。

```bash
# install.shが同じディレクトリにある場合
bash install.sh --target . --type {project_type}

# install.shがない場合（pm-harnesリポジトリからの直接セットアップ）
# 手動でcore/からコピー
```

配置後の確認:
- .claude/rules/ に3ファイルあるか
- .claude/hooks/ にスクリプトがあるか
- .claude/skills/ にスキルがあるか
- .claude/settings.json が存在するか
- state/ に初期JSONがあるか
- docs/ にテンプレートがあるか

### Step 3: Git初期化

```bash
# gitリポジトリでなければ初期化
git init

# .gitignore 生成
# state/CHANGELOG.json.count は追跡不要
```

**GitHub連携（オプション）**: ユーザーに確認してから実行。

```bash
# ユーザーが希望する場合のみ
gh repo create {project_name} --private --source=. --push
```

### Step 4: Schedule設定

以下のscheduleをユーザーに提案。承認されたものだけ設定:

| スケジュール | 内容 | 推奨タイミング |
|---|---|---|
| **weekly-report** | 週次レポート生成 | 毎週金曜 16:00 |
| **retro** | 振り返り | 毎週金曜 17:00 or 隔週 |

提案時:
「以下のscheduleを設定しますか？不要なものはスキップできます。」

設定方法: Claude Codeの `/schedule` コマンドを使用。

### Step 5: 初期コンテキスト投入

Step 1でヒアリングした内容を各ファイルに記入:
- state/STATUS.json: project_name, project_type, current_phase, last_updated
- docs/PROJECT.md: ゴール、スコープ
- docs/STAKEHOLDER.md: 関係者（consulting/system_devのみ）
- state/WBS.json: 初期マイルストーン（あれば）

### Step 6: 初回コミット + 確認

```bash
git add -A
git commit -m "PM-Harness: project setup ({project_type})"
```

ユーザーに完了報告:

```
PM-Harnessセットアップ完了！

✅ ファイル配置: rules/hooks/skills/state/docs
✅ Git初期化: {リポジトリ状況}
✅ Schedule: {設定した内容 or "なし"}
✅ 初期コンテキスト: STATUS.json, PROJECT.md

次のセッションから:
- セッション開始時にプロジェクト状況が自動表示されます
- セッション終了時にL1ルールFBが自動実行されます
- {schedule設定があれば} 毎週金曜にweekly-report/retroが自動実行されます

「情報集めて」「WBS作って」「リスクチェック」など、いつでも作業を始められます。
```
