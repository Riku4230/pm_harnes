# PM-Harness Design — Claude Code Harness Engineering for Project Management

> v4.0 — CEOレビュー反映版（SELECTIVE EXPANSION）

## 0. Overview

PM-Harnessは、PMの代替エージェントではない。
**PM業務の周囲にある制御システム**である。

プロジェクト文脈を集め、PM成果物を評価し、リスクとズレを検知し、
人間の注意を重要箇所へ向け、自分自身のガイド・センサー・ループ改善案を出し続ける。

基本はmarkdown + shell script + JSONで構成。
自動フィードバック（project-advisor-llm, self-improve）にのみClaude Agent SDKを使用する。

### 核心公式

```
Agent = Model + Harness
Harness = ①そもそもさせない + ②やった後に検知 + ③仕組み自体を改善
```

同一モデルでもハーネスの違いだけで6倍の性能差が生じる（Stanford Meta-Harness）。

---

## 1. 業務目的

Gota氏の4ステップの最初。これがないとハーネスは「不安への反応」になる。
目的が曖昧だと、制御は設計ではなく不安への反応になる。

### 何を守るか

- **関係者との認識齟齬を最小化する** — PM失敗原因の大半
- **意思決定とその根拠を追跡可能にする** — なぜその判断に至ったかを後から辿れる
- **リスクを早期検出し対応策を確保する** — 手遅れになる前に
- **プロジェクト知識をセッション間で保持する** — コンテキスト腐食を防ぐ

### 何を守らないか

- 成果物のフォーマット美化（内容が正しければ良い）
- 全タスクの詳細追跡（Notion/GitHub Issuesに委譲）
- 予算・コスト管理（スコープ外）

### どこで人が介入するか

- **外部ステークホルダーへの送信前** — AI→下書き→人間確認→送信。不可逆だから
- **リスク対応の優先順位決定** — trade-offは人間判断
- **プロジェクトスコープの変更判断** — 戦略的意思決定
- **ハーネス自体の変更** — ステアリングループの承認ゲート

---

## 2. 3層制御の体系

PM-Harnessの中心構造。全てのrules/hooks/skills/stateはこの3層のいずれかに属する。

```
強い ←──────────────────────────────────────→ 弱い

 ①そもそもさせない        ②やった後に検知する      ③仕組み自体を改善する
  (Computational Guide)     (Feedback Sensor)       (Steering Loop)
  構造で違反を不可能に       事後チェックで見つける     ①②を育て続ける
```

### ① そもそもさせない（構造で守る）

**指示ではなく仕組みで、間違いが起きない環境を作る。最も強い制御。**

Gota氏: 「違反が書けない形にできるなら最強。構造で守れるなら、指示は要らない。」

| やらせたくないこと | 実装 |
|---|---|
| 不正な形式のデータ作成 | JSONスキーマバリデーション（validate-state.sh） |
| 対応策なしのリスク登録 | RISK.jsonでmitigation必須化（スキーマで空文字禁止） |
| 勝手なドキュメント変更 | approval-gate.sh（PreToolUseでdocs/state/変更を検知） |
| 外部向けスキルがstate/を直接変更 | allowed-tools制限（draft-updateにWrite不許可） |
| 過去の意思決定の改ざん | CHANGELOG.jsonのappend-only制約（エントリ数減少をブロック） |
| 必要な情報を読まずにタスク実行 | Required Context（スキル発火時に強制Read） |
| コンテキスト肥大化 | Token Budget（10,000トークン/スキル上限） |

**原則**: rulesに「承認を取ってね」と書くのはInferential Guide（指示）。LLMが忘れたら機能しない。
可能な限り構造（hook/スキーマ/allowed-tools）に移す。

### ② やった後に検知する（Feedback Sensor）

**実行結果を検査し、問題があれば修正を促す。3層で頻度とコストを分離。**

| 層 | 頻度 | コスト | 検出対象 |
|---|---|---|---|
| **L1 ルールベース** | 毎セッション | ゼロ | 期限超過、未対応リスク、未共有期間、Decision Drift、Open Questions Aging、Source-of-Truth不一致 |
| **L2 LLMプロジェクトFB** | 日次（24h経過時） | 〜$0.05 | 意思決定矛盾、スケジュール非現実性、コミュニケーション懸念 |
| **Cross-Model Review** | 任意（手動起動） | 〜$0.10 | 単一モデルの盲点、リスク評価の偏り |

**センサー重症度**（全部同じ強度で扱うとPMがイラつく）:

| 重症度 | 動作 | 例 |
|---|---|---|
| **Block** | 作業を止める | 期限なしlaunchプラン、ownerなし重要タスク、明確なsource-of-truth矛盾 |
| **Warn** | 警告表示、作業は続行 | 成功指標が弱い、ステークホルダー確認不明、open question 7日超 |
| **Log** | 記録のみ、表示しない | 表現の曖昧さ、フォーマット崩れ、軽微な不整合 |

**設計原則**:
- Computational > Inferential — shellでチェックできるならLLMに頼らない
- Success is silent — 正常時は何も出力しない。異常時だけ詳細に
- L1で拾えないものだけL2に回す

### ③ 仕組み自体を改善する（Steering Loop）

**①と②で検出した問題を分析し、①②自身を改善する。ハーネスが育つ仕組み。**

```
問題が発生
  │
  ├── ①で防げたはず → Computational Guideを強化
  │   例: 「対応策なしリスク」が通った → スキーマにmitigation必須を追加
  │
  ├── ②で検出できたはず → Feedback Sensorを強化
  │   例: 「Slackチャンネル見落とし」 → L1にチャンネルリスト追加
  │
  └── ①②では対処不能 → 業務目的の見直し or 新しいトポロジー追加
```

**核心**: ステアリングの目的は**足すことより削ること**。
sensorは発火ログが残るから削除判断できる。guideは「読まれた？守られた？」が見えないから溜まりやすい。
だからguideは最初から少なく保ち、足すハードルを上げる。

---

## 3. 開発→PMの5つの違い

ハーネスエンジニアリングの文献は全て開発向け。PM業務に置き換える際の重要ポイント。

| # | 違い | 開発 | PM |
|---|---|---|---|
| 1 | **最大のリスク** | バグ（テストで検出可能） | **認識齟齬（テスト不可能、爆発するまで見えない）** |
| 2 | **デプロイ先** | サーバー | **人間の頭（共有しないと価値ゼロ）** |
| 3 | **成果物の性質** | コード（正しいか動かせば分かる） | **文書+合意（正しいかは主観）** |
| 4 | **コンテキスト腐食速度** | 週〜月単位（コミット時） | **日単位（会議・Slack・メールのたび）** |
| 5 | **操作の可逆性** | git revert可能 | **外部送信は不可逆** |

**結果**: 開発はComputational Sensorが豊富（テスト/lint/CI）。PMにはない。
だからこそ**構造で守れるところを最大化する**設計が開発以上に重要。

---

## 4. ディレクトリ構成

### 4.1 ハーネス本体（配布用）

```
pm-harness/
├── DESIGN.md                            ← この文書
├── install.sh                           ← プロジェクトへのインストーラ
├── core/
│   ├── rules/
│   │   ├── 01-pm-principles.md             PM判断原則（業務目的を含む）
│   │   ├── 02-context-routing.md            ポインタ表
│   │   └── 03-anti-patterns.md              やらかし記録
│   ├── hooks/
│   │   ├── session-start.sh                 STATUS + ALERTS + Bootstrap Check
│   │   ├── session-end.sh                   ログ + L1ルールFB + L2/L3起動判定
│   │   ├── validate-state.sh                state/*.jsonバリデーション
│   │   ├── approval-gate.sh                 docs/state/変更の承認ゲート
│   │   ├── project-advisor-rules.sh         L1: ルールベースFB（毎回）
│   │   ├── project-advisor-llm.ts           L2: LLMプロジェクトFB（日次、Agent SDK）
│   │   └── self-improve.ts                  L3: ハーネス自己改善（週次、Agent SDK）
│   └── skills/
│       ├── project-init/                    プロジェクト初期設定
│       ├── context-pack/                    情報収集（Slack/Notion/各種ソースから）
│       ├── meeting-import/                  議事録取り込み
│       ├── wbs-update/                      WBS管理
│       ├── risk-check/                      リスク管理
│       ├── draft-update/                    下書き生成（送信不可）
│       ├── context-sync/                    ドキュメント同期+矛盾検出
│       ├── context-review/                  ステアリング: 改善レビュー
│       └── cross-review/                    Cross-Model Review（Codex/subagent）
└── templates/
    ├── personal/
    ├── consulting/
    └── system_dev/
```

### 4.2 インストール後のプロジェクト

```
project-x/
├── CLAUDE.md                            ← 最小限（〜30行）
├── .claude/
│   ├── rules/                           ← 60行以下（Osmani基準）
│   │   ├── 01-pm-principles.md
│   │   ├── 02-context-routing.md
│   │   └── 03-anti-patterns.md
│   ├── hooks/
│   │   ├── session-start.sh
│   │   ├── session-end.sh
│   │   ├── validate-state.sh
│   │   ├── approval-gate.sh
│   │   ├── project-advisor-rules.sh
│   │   ├── project-advisor-llm.ts
│   │   └── self-improve.ts
│   ├── skills/
│   │   └── (上記と同じ)
│   └── settings.json
├── docs/                                ← 人間向けMarkdown（外部共有可能）
│   ├── PROJECT.md
│   ├── STAKEHOLDER.md
│   └── COMMUNICATION.md
├── state/                               ← AI向けJSON（構造化データ）
│   ├── STATUS.json
│   ├── RISK.json
│   ├── WBS.json
│   ├── CHANGELOG.json
│   ├── IMPROVEMENTS.json
│   ├── SESSION_LOG.json
│   ├── ALERTS.json
│   └── REVIEW_PROPOSALS.json
├── meeting/
└── workspace/
```

### 4.3 docs/ と state/ の分離原則

| | docs/ | state/ |
|---|---|---|
| 形式 | Markdown | JSON |
| 読者 | 人間 + AI | AIのみ |
| 外部共有 | Notion/Google Drive等に同期可 | 同期しない |
| 書き換えリスク | 高い | 低い（Anthropic: JSONの方が壊れにくい） |
| 内容 | 知識・方針・ルール | 状態・進捗・構造化データ・ログ |

---

## 5. Rules設計（60行以下）

rulesは全セッションで自動ロードされるため、ここに知識を入れてはいけない。

### 5.1 01-pm-principles.md（PM判断原則 〜25行）

```markdown
# PM Principles

## 業務目的
- 守る: 認識齟齬の最小化、意思決定の追跡可能性、リスク早期検出
- 守らない: フォーマット美化、全タスク詳細追跡、予算管理
- 人が介入: 外部送信前、リスク優先度、スコープ変更、ハーネス変更

## 行動原則
- 意思決定はユーザーに委ねる。提案は出すが勝手に決めない
- 不確実性がある場合は必ず明示する
- 成功時は静かに、異常検出時は詳しく報告する
- 改善点はstate/IMPROVEMENTS.jsonに記録する

## Compaction対策
コンテキスト圧縮後、まずstate/STATUS.jsonをReadして現在状態を把握する。
current_taskとcontext_notesフィールドに作業状態が記録されている。

## Token Budget
1回のスキル実行でReadするファイル合計は10,000トークン以内。
```

### 5.2 02-context-routing.md（ポインタ表 〜20行）

```markdown
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
| 改善レビュー | state/IMPROVEMENTS.json + state/SESSION_LOG.json |
```

### 5.3 03-anti-patterns.md（やらかし記録 〜15行）

```markdown
# Anti-Patterns

各エントリは「日付・インシデント・対策」を必ず含む。
トレースできないルールはノイズ。10件超でcontext-reviewにて剪定。

（初期状態は空。ステアリングループで育つ）
```

---

## 6. Hooks設計（実機確認済み）

### 6.1 利用可能なイベント

| イベント | 存在 | 用途 |
|---|---|---|
| SessionStart | ✓ | STATUS + ALERTS注入 + Bootstrap Check |
| SessionEnd | ✓ | SESSION_LOG + L1ルールFB + L2/L3起動判定 |
| PreToolUse | ✓ | docs/state/変更の承認ゲート |
| PostToolUse | ✓ | state/*.jsonバリデーション |
| Stop | ✓ | 使用しない（応答ごとに発火、頻度が高すぎる） |
| PreCompact/PostCompact | ✗ | 存在しない。rules指示で代替 |

### 6.2 ライフサイクル

```
SessionStart              → session-start.sh: STATUS + ALERTS + Bootstrap Check
  ▼
(作業中)
  ├── PreToolUse          → approval-gate.sh: docs/state/変更をBlock or Log
  ├── PostToolUse         → validate-state.sh: JSON整合性 + append-only確認
  ▼
SessionEnd                → session-end.sh: ログ + L1 + L2/L3起動判定
```

### 6.3 session-start.sh

SessionStart で発火。STATUS.json要約 + ALERTS.json表示 + Bootstrap Check。
additionalContextとして出力（3,000文字以内を目標）。

Bootstrap Check: state/ディレクトリ存在、必須JSONファイル存在を確認。
欠落があれば「project-initスキルを実行してください」と表示。

### 6.4 approval-gate.sh

PreToolUse(Edit|Write) で発火。docs/ or state/ への変更を検知。
settings.jsonのapproval_mode設定に応じてBlock(exit 2) or Log(exit 0)。
プリセット別デフォルト: personal=log, consulting/system_dev=log（重要スキルはblock検討）。

### 6.5 validate-state.sh

PostToolUse(Edit|Write) で発火。state/*.jsonの変更のみ検査。
JSON構文チェック + CHANGELOG.jsonのappend-only確認（エントリ数減少でexit 2）。

### 6.6 session-end.sh（3層FB統合）

SessionEnd で発火。以下を順次実行:

1. SESSION_LOG.json追記（100件ローテーション）
2. session_handoff: STATUS.jsonに主要意思決定+未完了作業を記録
3. L1: project-advisor-rules.sh（毎回）
4. L2: project-advisor-llm.ts（前回から24h経過時のみ、バックグラウンド）
5. L3: self-improve.ts（10件+3日 or 20件強制時のみ、バックグラウンド）

### 6.7 PM固有センサー（L1: project-advisor-rules.sh）

| センサー | チェック内容 | 重症度 |
|---|---|---|
| **期限超過検出** | WBS.jsonのdue < today && status != done | Warn(7日以内) / Block(7日超) |
| **未対応リスク** | RISK.jsonのmitigation空 && impact == high | Block |
| **未共有期間** | CHANGELOG.jsonの最新stakeholder_update > 14日前 | Warn |
| **Decision Drift** | CHANGELOG.jsonの過去決定 vs 最新STATUS.jsonの矛盾 | Warn |
| **Open Questions Aging** | STATUS.jsonのopen_questions: owner不在3日超、未解決7日超 | Warn |
| **Source-of-Truth不一致** | docs/の記述日 vs state/のデータ日の乖離 | Warn(30日超) |
| **IMPROVEMENTS蓄積** | IMPROVEMENTS.json件数 > 10 | Log（context-reviewを促す） |

### 6.8 LLMプロジェクトFB（L2: project-advisor-llm.ts）

日次（24h経過時）、Agent SDK(Sonnet)、〜$0.05/回。

検出対象:
- 意思決定間の意味的矛盾
- スケジュールの現実性（このペースで間に合うか）
- コミュニケーション上の懸念（共有漏れ、根回し不足）
- 「やるべきだがやっていないこと」

出力: state/ALERTS.jsonのllm_alertsフィールド。高確信のものだけ。

### 6.9 ハーネス自己改善（L3: self-improve.ts）

発火条件: (IMPROVEMENTS 10件以上 AND 前回から3日以上) OR 20件以上（強制）。
Agent SDK(Sonnet)、〜$0.10/回。

加賀谷氏のSelf-improve構造に対応:
- **check**: rules/skills/の整合性を決定論チェック
- **entropy**: docs/ ↔ state/の矛盾をLLM意味解析で検出
- **feedback-loop**: IMPROVEMENTS分析 → 改善提案生成

出力: state/REVIEW_PROPOSALS.json。全変更はユーザー承認後にcontext-reviewで適用。

### 6.10 settings.json

```json
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/session-start.sh"}]}
    ],
    "SessionEnd": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/session-end.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash .claude/hooks/approval-gate.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash .claude/hooks/validate-state.sh"}]}
    ]
  }
}
```

---

## 7. トポロジー × FF/FBペア設計

Ashbyの法則: トポロジーを限定して制御可能にする。PM業務を7つの型に限定。

### 7.1 一覧

| # | トポロジー | スキル | 入力 | 出力 | 構造制約（①） |
|---|---|---|---|---|---|
| 1 | 情報収集 | context-pack | Slack/Notion/各種 | 整理済み情報 | Read専用 |
| 2 | 議事録 | meeting-import | 会議文字起こし | 決定事項+TODO | 担当者STAKEHOLDER突合 |
| 3 | WBS管理 | wbs-update | 進捗情報 | 最新WBS | 循環検出+期限チェック |
| 4 | リスク管理 | risk-check | 各種状態 | リスク台帳 | mitigation必須スキーマ |
| 5 | 下書き生成 | draft-update | STATUS + RISK | 宛先別下書き | **Write/送信不許可** |
| 6 | ドキュメント同期 | context-sync | docs/ + state/ | 矛盾修正+更新 | メタデータ先読み |
| 7 | ステアリング | context-review | IMPROVEMENTS + PROPOSALS | ハーネス改善 | 人間承認必須 |

対象外: 予算管理、課題個別トラッキング（Notion/GitHub Issues）

### 7.2 各トポロジーのFF/FB

各スキルは「Required Context読み込み → 実行 → FB → Post」の4フェーズ。

#### 情報収集 (context-pack)

```
Required Context: state/STATUS.json
Token Budget: 〜3,000トークン
    ↓
実行: Slack MCP / Notion MCP / 各種ソースから情報収集 → 正規化 → 鮮度チェック
    ↓
FB-Computational [Warn]: 取得ソース数が想定より少ない場合
    ↓
Post: state/STATUS.json更新、state/CHANGELOG.json追記
```

#### 議事録 (meeting-import)

```
Required Context: docs/STAKEHOLDER.md
Token Budget: 〜2,000トークン（文字起こしは別途）
    ↓
実行: 文字起こし → 議事録 → 決定事項・TODO抽出
    ↓
FB-Computational [Block]: 決定事項0件 かつ TODO 0件
                 [Warn]: TODO担当者がSTAKEHOLDER.mdに不在
    ↓
Post: STATUS.json更新、CHANGELOG.json追記
```

#### WBS管理 (wbs-update)

```
Required Context: state/WBS.json + state/STATUS.json
Token Budget: 〜4,000トークン
    ↓
実行: 進捗反映 → WBS更新 → マイルストーン確認
    ↓
FB-Computational [Block]: 依存関係の循環検出
                 [Warn]: 期限超過タスク、日付不整合
    ↓
Post: STATUS.json更新
```

#### リスク管理 (risk-check)

```
Required Context: state/RISK.json + state/WBS.json
Token Budget: 〜3,000トークン
    ↓
実行: リスク再評価 → 新規リスク検出 → 対応策確認
    ↓
FB-Computational [Block]: 高リスクの対応策未定義（スキーマで構造的に防止）
                 [Warn]: リスク件数急増、30日未更新リスク
    ↓
Post: RISK.json更新
```

#### 下書き生成 (draft-update)

```
Required Context: docs/STAKEHOLDER.md + docs/COMMUNICATION.md + state/STATUS.json
Token Budget: 〜3,000トークン
allowed-tools: Read のみ（Write/Slack送信は不許可）
    ↓
実行: 宛先別に要約生成 → workspace/に下書き保存
    ↓
FB-Computational [Warn]: 宛先がSTAKEHOLDER.mdに不在
    ↓
Post: CHANGELOG.json追記（下書き生成の記録のみ。送信は人間が行う）
```

#### ドキュメント同期 (context-sync)

```
Required Context: docs/全ファイルのメタデータ（ファイル名+更新日のみ）
Token Budget: 〜2,000トークン（詳細は段階的に読む）
    ↓
実行: 更新日チェック → 古いファイル特定 → 該当ファイルのみ全文Read → 矛盾検出
    ↓
FB-Computational [Warn]: 30日以上前のファイル
                 [Log]: IMPROVEMENTS件数チェック（10件超で促す）
    ↓
Post: 修正提案をユーザーに提示（自動修正はしない）
```

---

## 8. Cross-Model Review

異なるモデルで同じ成果物をレビューし、単一モデルの盲点を補う。
Böckelerの2x2マトリクスにおけるInferential Feedbackの中で最も信頼性が高い。

前提条件: Codex CLI or Claude subagent（Agent tool）。
フォールバック: Codex不可ならsubagentで独立レビュー。

使い分け:
- risk-check → recommended（リスクの見落としは致命的）
- draft-update → recommended（外部向けは品質重要）
- meeting-import → optional
- wbs-update → not needed（Computational FBで十分）

---

## 9. 3層フィードバック + ステアリングループ

### 9.1 全体フロー

```
SessionEnd hook
  │
  ├── L1: project-advisor-rules.sh    毎回、shell、〜100ms
  │   「数字で検出できるプロジェクトの危険信号」
  │   + PM固有センサー（Decision Drift, Open Questions Aging, Source-of-Truth）
  │
  ├── L2: project-advisor-llm.ts      日次、Agent SDK(Sonnet)
  │   「文脈を読まないと分からないプロジェクトの危険信号」
  │
  └── L3: self-improve.ts             週次、Agent SDK(Sonnet)
      「ハーネス自体（rules/skills/hooks）の改善提案」
```

### 9.2 セッション開始時の表示

```
## Current Status
Project: X案件 / Phase: 設計 / Updated: 2026-04-25

## Alerts
  🔴 [rule] タスク'要件定義書レビュー'が5日超過
  🔴 [rule] 高リスク'ベンダー選定遅延'の対応策が未定義
  🟡 [llm] 4/20の『スコープ縮小』と4/23の『機能A追加』が矛盾
  🟡 [rule] open question 'API仕様' が7日間未回答

## Harness Improvement Proposals (3件)
  context-reviewを実行して適用してください
```

### 9.3 ステアリングのVerifyフェーズ

context-review適用後、該当トポロジー実行時にIMPROVEMENTSの同種インシデント再発を
L1で自動監視。2週間再発なしで「verified」マーク。

### 9.4 投資判断（加賀谷氏フレームワーク）

| 消えるもの（3-6ヶ月寿命） | 残るもの（長期投資対象） |
|---|---|
| Compaction workaround | ワークフロー定義（skills） |
| Context resets | ドメイン知識（docs/state/） |
| 特定モデル向けプロンプトハック | 評価の仕組み（FB sensor） |
| | **自己改善ループ（3層FB）** |

---

## 10. プロジェクトタイプ別プリセット

### Personal（日常・個人）

```
docs/: PROJECT.md のみ
state/: STATUS.json のみ
skills: context-pack, context-review
hooks: session-start, session-end（L1のみ）
```

### Consulting（コンサル・BPR・導入支援）

```
docs/: PROJECT.md, STAKEHOLDER.md, COMMUNICATION.md
state/: STATUS.json, RISK.json, WBS.json, CHANGELOG.json, IMPROVEMENTS.json,
        SESSION_LOG.json, ALERTS.json, REVIEW_PROPOSALS.json
skills: 全スキル有効
hooks: 全hook有効（L1+L2+L3）
```

### System Dev（システム開発）

```
docs/: Consulting全部 + SPEC.md
state/: Consulting全部 + BACKLOG.json
skills: 全スキル有効 + GitHub連携
hooks: 全hook有効
```

### project-initフロー

ヒアリング → タイプ自動判定 → テンプレートからディレクトリ生成 → 初期コンテキスト投入 → 確認。

---

## 11. CLAUDE.md（司令塔）

```markdown
# Project: {project_name}

project_type: {personal|consulting|system_dev}

## PM-Harness
- rules: .claude/rules/ （PM判断原則 + ルーティング + anti-patterns）
- hooks: .claude/hooks/ （セッション管理 + バリデーション + 3層FB）
- skills: .claude/skills/ （PMワークフロー）
- docs: docs/ （人間向け知識、JIT読み込み）
- state: state/ （AI向け構造化データ、JIT読み込み）

## Working Directory
作業はworkspace/で行う。成果物もここに格納。
議事録はmeeting/に格納。

## Key Constraints
- rulesは60行以下を維持する
- @参照は使わない（即時全読込されるため）
- 1スキル実行あたりのRead合計は10,000トークン以内
- 外部送信は人間が行う（AIは下書きまで）
```

---

## 12. 設計原則まとめ

### やること

| 原則 | 3層制御 | 実装 |
|---|---|---|
| PM Principles先行 | 前提 | §1で業務目的を明文化 |
| 構造で守る | ① | JSONスキーマ、allowed-tools、approval-gate、Required Context |
| Computational First | ② | まずL1ルールFB。L2 LLMは補助 |
| センサー重症度分類 | ② | Block/Warn/Logで注意を節約 |
| 3層フィードバック | ② | L1毎回+L2日次+Cross-Model任意 |
| Failure-to-Rule変換 | ③ | IMPROVEMENTS → anti-patterns昇格 |
| Human approval gate | ③ | ステアリング変更は人間承認必須 |
| Thin rules | 全体 | 60行以下。知識はdocs/、状態はstate/ |
| Token Budget | 全体 | 10,000トークン/スキル |
| Agent SDK限定利用 | ②③ | L2(project-advisor-llm)とL3(self-improve)のみ |

### やらないこと

| アンチパターン | 理由 |
|---|---|
| rulesに知識を書く | コンテキスト肥大化。JIT読み込みで代替 |
| @参照を使う | 遅延読込ではなく即時全読込される |
| 存在しないhookに依存 | PreCompact/PostCompact/SubagentStopは存在しない |
| Stopで改善蓄積 | 応答ごとに発火。SessionEndを使う |
| 自律的ルール書き換え | 暴走リスク。人間レビューゲート必須 |
| 全センサーをBlockに | PMがイラつく。重症度を分類する |
| AIが外部送信する | 不可逆。下書き生成まで。送信は人間 |

---

## 13. レビュー履歴

### v4.0 変更（CEOレビュー SELECTIVE EXPANSION）

| 変更 | 区分 |
|---|---|
| §1 業務目的（PM Principles）追加 | ACCEPTED |
| §2 3層制御の体系を中心構造に | ACCEPTED |
| §3 開発→PMの5つの違い追加 | ACCEPTED |
| PM固有センサー（Decision Drift, Open Questions Aging, Source-of-Truth）追加 | ACCEPTED |
| スキル名変更（context-pack, draft-update） | ACCEPTED |
| センサー重症度分類（Block/Warn/Log）追加 | ACCEPTED |
| PM版Four Keys | DEFERRED |
| Assumption Ledger | DEFERRED |

### v3.0 変更

3層フィードバック + Agent SDK統合。L1毎回、L2日次、L3週次。

### v2.0 変更

hooks API実機確認。PreCompact/PostCompact削除。approval-gate追加。Required Context追加。

---

## 14. 出典

| 出典 | 取り入れた要素 |
|---|---|
| Böckeler (Martin Fowler) | FF/FB、2x2マトリクス、Ashby、トポロジー、3領域、ステアリング |
| Gota | 目的ファースト4ステップ、構造>指示、肥大化との戦い |
| Anthropic | JSON>MD、Selective Reading、hooks API、Two-Agent |
| Osmani | 60行、Silent success、Progressive Disclosure |
| Hashimoto | Failure-to-Rule、ハーネス命名の起源 |
| 渋谷 (Algomatic) | SDLC視点、Four Keys、人・チームの仕組み |
| 加賀谷 (Asterminds) | Cross-Model Review、Self-improve 4層、投資判断 |
| 成瀬 (TAKT) | Faceted Prompting、Quality Gates、ツール権限制限 |
| すぅ (note) | CLAUDE.md司令塔、docs/構成、Slack集約、hooks改善蓄積 |
| miyatti (ai-plc) | install.sh配布、タイプ別適応、project-initフロー |
| Stanford Meta-Harness | 同一モデルでハーネス違い6倍差 |
| Google DeepMind AutoHarness | ハーネス自動合成 |
