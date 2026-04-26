# Context Routing

プロジェクト知識はdocs/とstate/にある。必要な場面でReadする。
@参照は使わない（即時全読込されコンテキストを圧迫するため）。

| 場面 | Readするファイル |
|---|---|
| セッション開始 | hooksが自動注入（手動不要） |
| タスク進捗確認 | state/STATUS.json + state/WBS.json |
| 誰に共有・相談 | docs/STAKEHOLDER.md |
| リスク議論 | state/RISK.json |
| 外部コミュニケーション | docs/COMMUNICATION.md + docs/STAKEHOLDER.md |
| 意思決定の経緯 | state/CHANGELOG.json |
| プロジェクト概要 | docs/PROJECT.md |
| 議事録の参照 | meeting/YYYY-MM-DD_会議名.md |
| 成果物の参照 | workspace/（下書き、レポート等） |
| 改善レビュー | state/IMPROVEMENTS.json + state/SESSION_LOG.json |

## フォルダ構成ルール

| フォルダ | 用途 | ファイル命名規則 |
|---|---|---|
| docs/ | 人間向けドキュメント（外部共有可） | PROJECT.md, STAKEHOLDER.md, COMMUNICATION.md |
| state/ | AI向け構造化データ（JSON） | STATUS.json, RISK.json, WBS.json 等 |
| meeting/ | 議事録 | YYYY-MM-DD_会議名.md |
| workspace/ | 作業成果物（下書き、レポート） | スキル名-YYYY-MM-DD.md（例: weekly-report-2026-04-25.md） |

## CHANGELOG.jsonエントリフォーマット

全スキルがCHANGELOG.jsonに追記する際は以下のフォーマットに従う:
```json
{"date": "YYYY-MM-DD", "type": "decision|stakeholder_update|risk_update|scope_change", "description": "内容"}
```
typeは必須。project-advisor-rules.shがtypeでフィルタする。
