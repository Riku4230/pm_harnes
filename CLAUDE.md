# Project: {project_name}

project_type: {project_type}

## PM-Harness

このプロジェクトはPM-Harness（AI-PMO）で管理されている。

### セッション開始時の動作（必須）
SessionStart hookがcontextにプロジェクト状況を注入する。
**最初の応答で必ず以下を表示してからユーザーの質問に答えること:**
1. hookから注入されたプロジェクト状況（Current Status, Alerts, Proposals）
2. git pullで取得したschedule実行の差分があれば表示
3. 表示後「何から始めますか？」または質問への回答

### 構成
- .claude/hooks/ — セッション管理 + バリデーション + 3層フィードバック（Codexと共有）
- .claude/rules/ — PM判断原則 + ルーティング + anti-patterns（60行以下）
- .claude/skills/ — PMワークフロー（12スキル）
- .codex/hooks.json — Codex CLI用フック設定（.claude/hooks/を参照）
- AGENTS.md — Codex CLI用指示ファイル（CLAUDE.md + rules統合）

### データ
- docs/ — 人間向けドキュメント（Markdown、外部共有可）
- state/ — AI向け構造化データ（JSON、スキーマ検証あり）
- sources/ — 外部ソース蓄積（YYYY-MM-DD.md）
- meeting/ — 議事録（YYYY-MM-DD_会議名.md）
- workspace/ — 作業成果物（下書き、レポート等）

### 制約
- rulesは60行以下を維持する
- @参照は使わない（即時全読込されるため）
- 1スキル実行あたりのRead合計は10,000トークン以内
- 外部送信は人間が行う（AIは下書きまで）
- state/JSONの編集はスキーマバリデーションが自動実行される

### 初回セットアップ
「セットアップして」→ /setup（ヒアリング→ファイル生成→Git/GitHub→Schedule）
