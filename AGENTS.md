# Project: {project_name}

project_type: {project_type}

## PM-Harness

このプロジェクトはPM-Harness（AI-PMO）で管理されている。
Codex CLI / Claude Code の両方で動作する。

### セッション開始時の動作（必須）
SessionStart hookがcontextにプロジェクト状況を注入する。
**最初の応答で必ず以下を表示してからユーザーの質問に答えること:**
1. hookから注入されたプロジェクト状況（Current Status, Alerts, Proposals）
2. git pullで取得したschedule実行の差分があれば表示
3. 表示後「何から始めますか？」または質問への回答

### 構成
- .claude/hooks/ — セッション管理 + バリデーション + 3層フィードバック（両CLI共有）
- .claude/rules/ — PM判断原則 + ルーティング + anti-patterns
- .claude/skills/ — PMワークフロー定義（12スキル）
- .codex/hooks.json — Codex用フック設定（.claude/hooks/を参照）

### データ
- docs/ — 人間向けドキュメント（Markdown、外部共有可）
- state/ — AI向け構造化データ（JSON、スキーマ検証あり）
- sources/ — 外部ソース蓄積（YYYY-MM-DD.md）
- meeting/ — 議事録（YYYY-MM-DD_会議名.md）
- workspace/ — 作業成果物（下書き、レポート等）

### 制約
- 1スキル実行あたりのRead合計は10,000トークン以内
- 外部送信は人間が行う（AIは下書きまで）
- state/JSONの編集はスキーマバリデーションが自動実行される（PreToolUseでブロック）
- 意思決定はユーザーに委ねる。提案は出すが勝手に決めない
- 不確実性がある場合は必ず明示する
- 改善点はstate/IMPROVEMENTS.jsonに記録する
- 高リスクには必ず対応策(mitigation)を定義する

### 初回セットアップ
「セットアップして」と言うと、ヒアリング→ファイル生成→Git/GitHub→Schedule を行う。
.claude/skills/setup/SKILL.md の手順に従うこと。

---

## Context Routing

プロジェクト知識はdocs/とstate/にある。必要な場面でReadする。

| 場面 | Readするファイル |
|---|---|
| タスク進捗 | state/STATUS.json + state/WBS.json |
| 誰に共有 | docs/STAKEHOLDER.md |
| リスク | state/RISK.json |
| 外部共有 | docs/COMMUNICATION.md + docs/STAKEHOLDER.md |
| 意思決定 | state/CHANGELOG.json |
| プロジェクト概要 | docs/PROJECT.md |
| 改善 | state/IMPROVEMENTS.json |

### CHANGELOGフォーマット
```json
{"date":"YYYY-MM-DD","type":"decision|stakeholder_update|risk_update|scope_change","description":"内容"}
```

---

## スキル（ワークフロー）

ユーザーが以下のトリガーワードを使ったら、対応する .claude/skills/*/SKILL.md を読んで手順に従うこと。

| トリガー | スキル | 読むファイル |
|---|---|---|
| 「セットアップして」「初期設定」 | setup | .claude/skills/setup/SKILL.md |
| 「情報取ってきて」「Slack同期」「ソース同期」 | source-sync | .claude/skills/source-sync/SKILL.md |
| 「ドキュメント確認して」「整合性チェック」 | doc-check | .claude/skills/doc-check/SKILL.md |
| 「議事録取り込んで」「会議まとめて」 | meeting-import | .claude/skills/meeting-import/SKILL.md |
| 「WBS更新して」「進捗更新」「タスク更新」 | wbs-update | .claude/skills/wbs-update/SKILL.md |
| 「タスク分解して」「サブタスク作って」「もっと細かく」 | decompose | .claude/skills/decompose/SKILL.md |
| 「リスクチェックして」「リスク確認」 | risk-check | .claude/skills/risk-check/SKILL.md |
| 「報告の下書き作って」「進捗報告の下書き」 | draft-update | .claude/skills/draft-update/SKILL.md |
| 「改善レビューして」「ハーネス改善」 | context-review | .claude/skills/context-review/SKILL.md |
| 「レビューして」「セカンドオピニオン」 | cross-review | .claude/skills/cross-review/SKILL.md |
| 「振り返りして」「レトロスペクティブ」 | retro | .claude/skills/retro/SKILL.md |
| 「週報作って」「今週のまとめ」 | weekly-report | .claude/skills/weekly-report/SKILL.md |

---

## Anti-Patterns

各エントリは「日付・インシデント・対策」を必ず含む。（ステアリングループで育つ）

## Compaction対策
コンテキスト圧縮後、まずstate/STATUS.jsonをReadして現在状態を把握する。
