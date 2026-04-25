---
name: project-init
description: 新しいプロジェクトの初期設定。ヒアリング→タイプ判定→ディレクトリ生成→初期コンテキスト投入。
when_to_use: 「新しいプロジェクトを始めたい」「プロジェクト初期化」「セットアップ」
---

# project-init

## ワークフロー

### Step 1: ヒアリング
以下を確認する:
- プロジェクト名
- どんなプロジェクトか → タイプ自動判定（personal / consulting / system_dev）
- ゴール
- 関係者（consulting/system_devのみ）
- 期限（consulting/system_devのみ）

### Step 2: ディレクトリ生成
タイプに応じたテンプレートからディレクトリを生成:
- CLAUDE.md
- .claude/rules/ （core/rules/からコピー）
- .claude/hooks/ （core/hooks/からコピー）
- .claude/skills/ （core/skills/からコピー）
- .claude/settings.json
- docs/ （タイプに応じたテンプレート）
- state/ （タイプに応じた初期JSON）
- meeting/
- workspace/

### Step 3: 初期コンテキスト投入
ヒアリング内容をdocs/state/に記入:
- docs/PROJECT.md にプロジェクト概要
- docs/STAKEHOLDER.md に関係者（consulting/system_devのみ）
- state/STATUS.json に初期状態
- state/WBS.json に初期マイルストーン（consulting/system_devのみ）

### Step 4: 確認
生成結果をユーザーに提示。承認後に完了。
