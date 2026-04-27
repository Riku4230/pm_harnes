# PM-Harness Design v0.1

PM業務の周囲にある制御システム（AI-PMO）の設計書。

---

## 1. 業務目的

| 問い | 答え |
|---|---|
| **何を守るか** | 認識齟齬の最小化、意思決定の追跡可能性、リスク早期検出 |
| **何を守らないか** | フォーマット美化、全タスク詳細追跡、予算管理 |
| **人が介入するか** | 外部送信前、リスク優先度、スコープ変更、ハーネス変更 |

---

## 2. 3層制御

```
①そもそもさせない → ②やった後に検知 → ③仕組み自体を改善
  (構造で防ぐ)        (センサーで検出)     (ステアリングで育てる)
```

### ① そもそもさせない

| 手段 | 実装 |
|---|---|
| JSONスキーマ | pre-validate-state.sh(PreToolUse): RISK mitigation必須、WBS循環検出、CHANGELOG append-only |
| 承認ゲート | approval-gate.sh: skills/hooks/ → Block、rules/ → Warning（context-review許可） |
| Required Context | 各スキルのSKILL.mdに強制読み込みリスト |
| Token Budget | rules: 1スキル10,000トークン以内 |

### ② やった後に検知

| 層 | 頻度 | 実装 | コスト |
|---|---|---|---|
| **L1 ルールFB** | 毎セッション終了 | project-advisor-rules.sh（7センサー） | ゼロ |
| **L2 LLM FB** | 6h間隔 | stop-advisor.sh → claude -p（Sonnet） | 〜$0.05 |
| **Cross-Model** | 任意（手動） | cross-reviewスキル | 〜$0.10 |

L1センサー:
1. 期限超過タスク
2. 未対応高リスク
3. ステークホルダー未共有14日超
4. Decision Drift
5. Open Questions Aging（3日owner不在、7日未解決）
6. Source-of-Truth不一致
7. IMPROVEMENTS蓄積10件超

### ③ 仕組み自体を改善

```
IMPROVEMENTS蓄積 → retro（週次）→ ハーネス改善適用
  同じミス3回 → anti-patternsに昇格
  不要ルール → 3ヶ月未発火で剪定
```

---

## 3. フォルダ構成

```
project/
├── CLAUDE.md                  プロジェクト概要
├── .claude/
│   ├── rules/                 PM判断原則（60行以下）
│   │   ├── 01-pm-principles.md
│   │   ├── 02-context-routing.md
│   │   └── 03-anti-patterns.md
│   ├── hooks/                 自動実行
│   │   ├── session-start.sh      SessionStart: git pull + STATUS + ALERTS
│   │   ├── session-end.sh        SessionEnd: transcript解析 + L1
│   │   ├── stop-advisor.sh       Stop: L2/L3起動判定
│   │   ├── approval-gate.sh      PreToolUse: skills/hooks/→Block, rules/→Warning
│   │   ├── pre-validate-state.sh PreToolUse: JSONスキーマ検証（ブロック可）
│   │   └── validate-state.sh     PostToolUse: Impact Analysis（advisory）
│   ├── skills/                12スキル
│   │   ├── setup/                初回セットアップ
│   │   ├── source-sync/          外部ソース情報取得
│   │   ├── meeting-import/       議事録取り込み
│   │   ├── wbs-update/           WBS管理
│   │   ├── decompose/            タスク分解（1-2日粒度）
│   │   ├── risk-check/           リスク管理
│   │   ├── draft-update/         下書き生成（送信不可）
│   │   ├── doc-check/            ドキュメント整合性確認
│   │   ├── context-review/       手動ステアリング
│   │   ├── cross-review/         Cross-Modelレビュー
│   │   ├── retro/                振り返り+改善適用
│   │   └── weekly-report/        週次レポート
│   └── settings.json          hooks登録
├── docs/                      人間向けMarkdown
├── state/                     AI向けJSON（スキーマ検証あり）
├── sources/                   外部ソース蓄積（YYYY-MM-DD.md）
├── meeting/                   議事録（YYYY-MM-DD_会議名.md）
├── workspace/                 作業成果物
└── templates/                 setupが参照するテンプレート
```

---

## 4. Hooks

### 発火タイミング

| イベント | hook | やること |
|---|---|---|
| SessionStart | session-start.sh | git pull → schedule差分表示 → STATUS要約 → ALERTS → PROPOSALS |
| PreToolUse(Edit|Write) | approval-gate.sh | skills/hooks/ → Block、rules/ → Warning |
| PreToolUse(Edit|Write) | pre-validate-state.sh | state/*.json スキーマ検証 → Block |
| PostToolUse(Edit|Write) | validate-state.sh | Impact Analysis（advisory警告のみ） |
| SessionEnd | session-end.sh | transcript解析 → SESSION_LOG → L1ルールFB |
| Stop | stop-advisor.sh | L2（6h経過時）/ L3（10件+3日 or 20件）をclaude -pでバックグラウンド起動 |

### L2/L3の起動方式

stop-advisor.shが条件判定し、`claude -p`でSonnetをバックグラウンド起動:
- L2: state/を読んで危険信号検出 → ALERTS.jsonのllm_alertsに書き出し
- L3: IMPROVEMENTS分析 → REVIEW_PROPOSALS.jsonに書き出し
- `--allowedTools "Read,Write"` でstate/のみ操作
- 未セットアップ時はスキップ

---

## 5. スキル一覧

| スキル | やること | 権限 |
|---|---|---|
| setup | ヒアリング→ファイル動的生成→Git/GitHub→Schedule | full |
| source-sync | Slack/Notion等から情報取得→sources/YYYY-MM-DD.mdに蓄積 | edit |
| meeting-import | 議事録→決定事項+TODO抽出 | edit |
| wbs-update | WBS進捗更新・マイルストーン確認 | edit |
| decompose | タスクを1-2日粒度のサブタスクに分解 | edit |
| risk-check | リスク再評価・対応策確認 | edit |
| draft-update | ステークホルダー向け下書き生成（送信不可） | edit |
| doc-check | docs/ ↔ state/ 整合性確認 | readonly |
| context-review | 手動ステアリング実行 | full |
| cross-review | Codex/subagentで独立レビュー | readonly |
| retro | 振り返り+ハーネス改善適用 | full |
| weekly-report | 週次レポート生成 | edit |

---

## 6. Schedule

| スケジュール | タイミング | Git運用 |
|---|---|---|
| source-sync | 毎日 9:00 | mainに直接push |
| weekly-report | 毎週金曜 16:00 | mainに直接push |
| retro（schedule） | 毎週金曜 17:00 | mainに直接push（分析+レポートのみ） |
| retro（手動） | 任意 | ハーネス改善あり→別ブランチ+PR |

session-start.shが次回セッション開始時にgit pullして差分を表示。

---

## 7. JSONスキーマ（pre-validate-state.sh）

| ファイル | 検証内容 |
|---|---|
| STATUS.json | project_name, project_type 必須 |
| RISK.json | name必須、impact/probability enum、high-impactはmitigation必須 |
| WBS.json | name必須、status enum、start_date < due、依存関係循環検出 |
| CHANGELOG.json | entries[].date/description必須、append-only |

---

## 8. 既知の制約

| 制約 | 理由 |
|---|---|
| allowed-toolsは権限付与であり制限ではない | Claude Codeの仕様。draft-updateの「送信不可」はスキル指示に依存 |
| hookからセッション内容に直接アクセス不可 | transcript_pathでの事後解析で代替 |
| agent hook（experimental）は未使用 | stop-advisor.shのclaude -pで代替 |

---

## 9. Codex CLI対応

hooks/スクリプトはClaude Code / Codex CLI両対応。

### 差分マッピング

| 項目 | Claude Code | Codex CLI |
|---|---|---|
| 設定ファイル | .claude/settings.json | .codex/hooks.json |
| 指示ファイル | CLAUDE.md + .claude/rules/ | AGENTS.md（統合版） |
| ツール名 | Edit, Write | apply_patch（Edit/Writeマッチャー互換） |
| スキル | .claude/skills/（自動読込） | AGENTS.mdにトリガー表記載 → 手動でSKILL.md参照 |
| SessionEnd | 専用イベント | なし（Stopで代替） |
| 環境変数 | CLAUDE_PROJECT_DIR | なし（stdinのcwdで取得、hooksは`.`にfallback） |
| L2/L3バックグラウンド | claude -p | codex -q（要検証） |

### hookスクリプトの互換設計
- ファイルパス取得: apply_patchのパッチ本文からも抽出可能
- CWD: `${CLAUDE_PROJECT_DIR:-.}` で両CLI対応
- PreToolUse exit 2: 両CLIでブロック動作
- スキル: Codexではスキル自動読込なし → AGENTS.mdのトリガー表でルーティング

---

## 10. 出典

Böckeler (Martin Fowler), Gota, Osmani, Hashimoto, 加賀谷 (Asterminds),
成瀬 (TAKT), Anthropic, すぅ (note), miyatti (ai-plc),
Stanford Meta-Harness, Google DeepMind AutoHarness
