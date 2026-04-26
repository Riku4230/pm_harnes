# Context Routing

プロジェクト知識はdocs/とstate/にある。必要な場面でReadする。
@参照は使わない（即時全読込されるため）。

| 場面 | Readするファイル |
|---|---|
| セッション開始 | hooksが自動注入（手動不要） |
| タスク進捗 | state/STATUS.json + state/WBS.json |
| 誰に共有 | docs/STAKEHOLDER.md |
| リスク | state/RISK.json |
| 外部共有 | docs/COMMUNICATION.md + docs/STAKEHOLDER.md |
| 意思決定 | state/CHANGELOG.json |
| プロジェクト概要 | docs/PROJECT.md |
| 議事録 | meeting/YYYY-MM-DD_会議名.md |
| 成果物 | workspace/ |
| 改善 | state/IMPROVEMENTS.json |
| ソース設定 | state/SOURCES.json |
| ソース情報 | sources/YYYY-MM-DD.md |

## フォルダルール

| フォルダ | 命名規則 |
|---|---|
| docs/ | PROJECT.md, STAKEHOLDER.md, COMMUNICATION.md |
| state/ | *.json（スキーマ検証あり） |
| meeting/ | YYYY-MM-DD_会議名.md |
| workspace/ | スキル名-YYYY-MM-DD.md |
| sources/ | YYYY-MM-DD.md（1日1ファイル） |

## CHANGELOGフォーマット
```json
{"date":"YYYY-MM-DD","type":"decision|stakeholder_update|risk_update|scope_change","description":"内容"}
```
