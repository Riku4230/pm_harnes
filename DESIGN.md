# PM Harness Design — Claude Code Harness Engineering for Project Management

> v3.0 — 3層フィードバック + Agent SDK統合

## 0. Overview

PM業務をClaude Code nativeで行うためのハーネス設計。
基本はmarkdown + shell script + JSONで構成。
自動フィードバック（project-advisor-llm, self-improve）にのみClaude Agent SDKを使用する。

### 設計根拠

| 出典 | 取り入れた原則 |
|---|---|
| Böckeler (Martin Fowler) | FF/FBペア設計、Ashbyの法則によるトポロジー限定、Computational > Inferential |
| Anthropic公式 | JSON > Markdown（状態管理）、Selective Reading、additionalContext上限、@参照の即時読込問題 |
| Osmani | 60行ルール、Success is silent / Failures are verbose、Progressive Disclosure |
| Hashimoto | Failure-to-Rule変換（ミス→インフラ改善） |
| Asterminds (加賀谷) | Cross-Model Review、Self-improve、投資判断（消えるもの vs 残るもの） |
| すぅ (note記事) | CLAUDE.md司令塔、docs/構成、Slack集約→Claude Code整理、hooks改善蓄積 |
| miyatti (ai-plc) | install.sh配布方式、プロジェクトタイプ別適応、project-initフロー |

### 核心公式

```
Agent = Model + Harness
Harness = Feedforward（事前ガイド） + Feedback（事後センサー） + Steering Loop（自己改善）
```

同一モデルでもハーネスの違いだけで6倍の性能差が生じる（Stanford Meta-Harness）。

---

## 1. ディレクトリ構成

### 1.1 ハーネス本体（配布用）

```
pm-harness/
├── DESIGN.md                            ← この文書
├── install.sh                           ← プロジェクトへのインストーラ
├── core/
│   ├── rules/
│   │   ├── 01-pm-behavior.md               行動原則
│   │   ├── 02-context-routing.md            ポインタ表
│   │   └── 03-anti-patterns.md              やらかし記録
│   ├── hooks/
│   │   ├── session-start.sh                 STATUS.json + ALERTS.json注入
│   │   ├── session-end.sh                   SESSION_LOG + ルールチェック + 自動FB起動
│   │   ├── validate-state.sh                state/*.jsonバリデーション
│   │   ├── approval-gate.sh                 state/docs/変更の承認チェック
│   │   ├── project-advisor-rules.sh         ルールベースプロジェクトFB（毎回）
│   │   ├── project-advisor-llm.ts           LLMベースプロジェクトFB（日次、Agent SDK）
│   │   └── self-improve.ts                  ハーネス自己改善（週次、Agent SDK）
│   └── skills/
│       ├── project-init/                    プロジェクト初期設定
│       ├── daily-report/                    日報生成
│       ├── meeting-import/                  議事録取り込み
│       ├── wbs-update/                      WBS管理
│       ├── risk-check/                      リスク管理
│       ├── stakeholder-update/              ステークホルダー通知
│       ├── context-sync/                    ドキュメント同期+矛盾検出
│       ├── context-review/                  ステアリング: 改善レビュー（手動起動）
│       └── cross-review/                    Cross-Model Review（Codex）
└── templates/
    ├── personal/
    ├── consulting/
    └── system_dev/
```

### 1.2 インストール後のプロジェクト

```
project-x/
├── CLAUDE.md                            ← 最小限（〜30行）
├── .claude/
│   ├── rules/                           ← 60行以下（Osmani基準）
│   │   ├── 01-pm-behavior.md
│   │   ├── 02-context-routing.md
│   │   └── 03-anti-patterns.md
│   ├── hooks/                           ← 4 hook + 3 自動FB（Agent SDK）
│   │   ├── session-start.sh                SessionStart: STATUS + ALERTS注入
│   │   ├── session-end.sh                  SessionEnd: ログ + ルールFB + 自動FB起動
│   │   ├── validate-state.sh               PostToolUse: JSONバリデーション
│   │   ├── approval-gate.sh                PreToolUse: 承認ゲート
│   │   ├── project-advisor-rules.sh        毎回: ルールベースプロジェクトFB
│   │   ├── project-advisor-llm.ts          日次: LLMプロジェクトFB（Agent SDK）
│   │   └── self-improve.ts                 週次: ハーネス自己改善（Agent SDK）
│   ├── skills/                          ← PM特化スキル群
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
│   ├── ALERTS.json                         プロジェクトFB結果（rule + LLM）
│   └── REVIEW_PROPOSALS.json               ハーネス改善提案（self-improve結果）
├── meeting/
└── workspace/
```

### 1.3 v1からの主な変更

| 変更 | 理由 |
|---|---|
| PreCompact/PostCompact hook削除 | Claude Code APIに存在しない。代替はrules指示 |
| HANDOFF.json削除 | hookからコンテキスト取得不可。STATUS.jsonで代替 |
| approval-gate.sh追加（PreToolUse） | state/docs/変更の承認ゲートを強制 |
| CHANGELOG.md → state/CHANGELOG.json | 構造化データはJSON（フィルタ・検索に必要） |
| 各スキルにRequired Contextセクション追加 | FFの指示依存を解消、強制読み込み |
| Token Budget指針追加 | コンテキスト肥大化防止 |
| SESSION_LOGローテーション追加 | 肥大化防止 |

### 1.4 docs/ と state/ の分離原則

| | docs/ | state/ |
|---|---|---|
| 形式 | Markdown | JSON |
| 読者 | 人間 + AI | AIのみ |
| 外部共有 | Notion/Google Drive等に同期可 | 同期しない |
| 書き換えリスク | 高い（Markdownは意図しない上書きが起きやすい） | 低い（Anthropic: JSONの方が壊れにくい） |
| 内容 | 知識・方針・ルール | 状態・進捗・構造化データ・ログ |
| 承認ゲート | PreToolUse hookで変更時に確認 | 同左 |

---

## 2. Rules設計（60行以下）

ハーネスの肥大化を防ぐ最重要ポイント。
rulesは全セッションで自動ロードされるため、ここに知識を入れてはいけない。

### 2.1 01-pm-behavior.md（行動原則 〜25行）

```markdown
# PM行動原則

- PMとして振る舞う。成果物の品質とプロジェクト成功を最優先する
- 意思決定はユーザーに委ねる。提案は出すが勝手に決めない
- 不確実性がある場合は必ず明示する
- 成功時は静かに、異常検出時は詳しく報告する（Success is silent）
- 改善すべき点を見つけたら、直接修正せずstate/IMPROVEMENTS.jsonに記録する
- スキル実行後、docs/state/に更新すべき情報がないか確認する

## Compaction対策
コンテキストが圧縮された場合、まずstate/STATUS.jsonをReadして現在状態を把握する。
STATUS.jsonのcurrent_taskとcontext_notesフィールドに作業状態が記録されている。

## Token Budget
1回のスキル実行でReadするファイルの合計は10,000トークン（約7,500文字）以内に抑える。
state/のJSONが巨大な場合は、必要なフィールドだけをjqで抽出するか、サマリーを先に読む。
```

### 2.2 02-context-routing.md（ポインタ表 〜20行）

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

### 2.3 03-anti-patterns.md（やらかし記録 〜15行）

```markdown
# Anti-Patterns

各エントリは「日付・インシデント・対策」を必ず含む。
トレースできないルールはノイズ（Osmani: "trace to specific past failures"）。
10件を超えたらcontext-reviewで剪定する。

（初期状態は空。ステアリングループで育つ）
```

---

## 3. Hooks設計（実機確認済み）

### 3.1 利用可能なイベント（Claude Code API確認済み）

| イベント | 存在 | 用途 |
|---|---|---|
| SessionStart | ✓ | STATUS.json要約注入 |
| SessionEnd | ✓ | SESSION_LOG + IMPROVEMENTS蓄積 |
| PreToolUse | ✓ | state/docs/変更の承認ゲート |
| PostToolUse | ✓ | state/*.jsonバリデーション |
| Stop | ✓ | 使用しない（応答ごとに発火、頻度が高すぎる） |
| UserPromptSubmit | ✓ | 将来拡張用（現在は未使用） |
| **PreCompact** | **✗** | **存在しない。rules指示で代替** |
| **PostCompact** | **✗** | **存在しない。rules指示で代替** |
| **SubagentStop** | **✗** | **存在しない** |

### 3.2 ライフサイクルと発火タイミング

```
SessionStart                 ← セッション開始・再開
  │                             → session-start.sh: STATUS.json要約注入
  ▼
(作業中)
  │
  ├── PreToolUse(Edit|Write) ← docs/state/への変更前
  │                             → approval-gate.sh: 変更対象を確認に表示
  │
  ├── PostToolUse(Edit|Write)← state/*.json編集後
  │                             → validate-state.sh: JSON整合性チェック
  ▼
SessionEnd                   ← セッション終了時
                                → session-end.sh: SESSION_LOG追記 + IMPROVEMENTS蓄積
```

### 3.3 session-start.sh

```bash
#!/bin/bash
# SessionStart で発火
# additionalContextとして出力（3,000文字以内を目標）
set -e
CWD="${CLAUDE_CWD:-.}"
STATUS="$CWD/state/STATUS.json"

if [ ! -f "$STATUS" ]; then
  echo "No STATUS.json found. Run project-init skill first."
  exit 0
fi

python3 -c "
import json, sys
try:
    with open('$STATUS') as f:
        s = json.load(f)
    print('## Current Status')
    print(f\"Project: {s.get('project_name', 'N/A')}\")
    print(f\"Type: {s.get('project_type', 'N/A')}\")
    print(f\"Phase: {s.get('current_phase', 'N/A')}\")
    print(f\"Updated: {s.get('last_updated', 'N/A')}\")
    ct = s.get('current_task')
    if ct:
        print(f\"Current Task: {ct}\")
    cn = s.get('context_notes')
    if cn:
        print(f\"Notes: {cn}\")
    if s.get('blockers'):
        print('Blockers: ' + ', '.join(str(b) for b in s['blockers']))
    if s.get('next_actions'):
        print('Next: ' + ', '.join(str(a) for a in s['next_actions'][:3]))
except Exception as e:
    print(f'Warning: Failed to read STATUS.json: {e}', file=sys.stderr)
"
```

### 3.4 approval-gate.sh

```bash
#!/bin/bash
# PreToolUse(Edit|Write) で発火
# state/ または docs/ への変更を検知してログ出力
# 終了コード0で続行、2でブロック
set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

case "$TOOL_NAME" in
  */state/*|*/docs/*)
    echo "PM Harness: Modifying $TOOL_NAME"
    exit 0  # ログのみ。ブロックが必要ならexit 2
    ;;
  *)
    exit 0
    ;;
esac
```

### 3.5 session-end.sh

```bash
#!/bin/bash
# SessionEnd で発火
set -e
CWD="${CLAUDE_CWD:-.}"
LOG_PATH="$CWD/state/SESSION_LOG.json"

python3 -c "
import json, datetime, os

log_path = '$LOG_PATH'
try:
    log = json.load(open(log_path)) if os.path.exists(log_path) else {'sessions': []}
except:
    log = {'sessions': []}

log['sessions'].append({
    'timestamp': datetime.datetime.now().isoformat(),
    'session_id': os.environ.get('SESSION_ID', 'unknown')
})

# ローテーション: 最新100件のみ保持
if len(log['sessions']) > 100:
    log['sessions'] = log['sessions'][-100:]

with open(log_path, 'w') as f:
    json.dump(log, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true
```

### 3.6 validate-state.sh

```bash
#!/bin/bash
# PostToolUse(Edit|Write) で発火
# state/*.json の JSON構文チェック
set -e
CWD="${CLAUDE_CWD:-.}"
STATE_DIR="$CWD/state"

if [ ! -d "$STATE_DIR" ]; then
  exit 0
fi

# state/ 配下の変更のみチェック（stdin からツール入力を読んでフィルタ）
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

case "$FILE_PATH" in
  */state/*.json)
    if [ -f "$FILE_PATH" ]; then
      python3 -c "import json; json.load(open('$FILE_PATH'))" 2>&1
      if [ $? -ne 0 ]; then
        echo "ERROR: $FILE_PATH is invalid JSON" >&2
        exit 2  # ブロック: 不正なJSONの書き込みを阻止
      fi
    fi
    ;;
esac
exit 0
```

### 3.7 settings.json（hooks登録）

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-start.sh"}]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-end.sh"}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/approval-gate.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/validate-state.sh"}]
      }
    ]
  }
}
```

### 3.8 Compaction対策（hookなしの代替設計）

PreCompact/PostCompact hookは存在しないため、rules指示で代替する。

**01-pm-behavior.md のCompaction対策セクション（§2.1に記載済み）:**
- LLMにSTATUS.jsonの`current_task`と`context_notes`を作業中に更新させる
- compaction後にruleが再読み込みされ、「STATUS.jsonを読め」と指示
- これにより状態復元が半自動的に行われる

**スキル内での対策:**
- 各スキルの冒頭でRequired Context（後述§4.3）を強制読み込み
- スキル実行中のcompactionでもコンテキストが復元される

---

## 4. トポロジー × FF/FBペア設計

Ashbyの法則: 制御系は対象と同等の多様性が必要。
PM業務を6つの型（トポロジー）に限定し、各々にFF+FBペアを設計する。

### 4.1 一覧

| # | トポロジー | スキル | 入力 | 出力 |
|---|---|---|---|---|
| 1 | 日報 | daily-report | Slack情報 | 日次レポート |
| 2 | 議事録 | meeting-import | 会議文字起こし | 決定事項+TODO |
| 3 | WBS管理 | wbs-update | 進捗情報 | 最新WBS |
| 4 | リスク管理 | risk-check | 各種状態 | リスク台帳 |
| 5 | ステークホルダー | stakeholder-update | STATUS + RISK | 宛先別通知 |
| 6 | ドキュメント同期 | context-sync | docs/ + state/ | 矛盾修正 + 更新 |

対象外（明示的スコープ外）: 予算・コスト管理、課題の個別トラッキング（Notion/GitHub Issuesで外部管理）

### 4.2 FF/FBペア詳細

各スキルは「Required Context読み込み → 実行 → FB（事後センサー）→ Post処理」の4フェーズ。

FB層はまず**Computational（決定論的）のみで開始**し、運用しながらInferentialを段階的に追加する。
FB-CrossModel（Codex）は独立したcross-reviewスキルで任意実行とし、各スキルに内蔵しない。

#### トポロジー1: 日報 (daily-report)

```
Required Context:
  - state/STATUS.json
  - docs/COMMUNICATION.md
  Token Budget: 〜3,000トークン
      ↓
実行: Slack MCPから情報収集 → 日報生成
      ↓
FB-Computational:
  - 必須セクション存在チェック（進捗/決定事項/リスク/明日の予定）
  - Slackチャンネル網羅率チェック（取得チャンネル数 vs 登録チャンネル数）
      ↓
Post: state/STATUS.json更新、state/CHANGELOG.json追記（重要決定があれば）
```

#### トポロジー2: 議事録 (meeting-import)

```
Required Context:
  - docs/STAKEHOLDER.md
  Token Budget: 〜2,000トークン（文字起こしは別途）
      ↓
実行: 文字起こしファイル → 議事録生成 → 決定事項・TODO抽出
      ↓
FB-Computational:
  - 決定事項とTODOの存在チェック（0件なら警告）
  - TODO担当者がSTAKEHOLDER.mdに存在するか（文字列マッチ）
      ↓
Post: state/STATUS.json更新、state/CHANGELOG.json追記
```

#### トポロジー3: WBS管理 (wbs-update)

```
Required Context:
  - state/WBS.json
  - state/STATUS.json
  Token Budget: 〜4,000トークン
      ↓
実行: 進捗情報を反映 → WBS更新 → マイルストーン確認
      ↓
FB-Computational:
  - 依存関係の循環検出（WBS.jsonのdependenciesフィールド）
  - 期限超過タスクの自動検出（due < today && status != done）
  - 日付整合性（start_date < end_date）
      ↓
Post: state/STATUS.json更新（次フェーズ情報）
```

#### トポロジー4: リスク管理 (risk-check)

```
Required Context:
  - state/RISK.json
  - state/WBS.json（スケジュールリスク用）
  Token Budget: 〜3,000トークン
      ↓
実行: リスクの再評価 → 新規リスクの検出 → 対応策の確認
      ↓
FB-Computational:
  - 対応策未定リスクの検出（mitigation == null or ""）
  - リスク件数の急増検知（前回実行時との差分）
  - 直近30日間未更新リスクのアラート
      ↓
Post: state/RISK.json更新
```

#### トポロジー5: ステークホルダー通知 (stakeholder-update)

```
Required Context:
  - docs/STAKEHOLDER.md
  - docs/COMMUNICATION.md
  - state/STATUS.json
  Token Budget: 〜3,000トークン
      ↓
実行: 宛先別に要約生成 → Slack/メール向けフォーマット変換
      ↓
FB-Computational:
  - 宛先がSTAKEHOLDER.mdに存在するか
  - テンプレート必須項目の存在チェック
      ↓
Post: state/CHANGELOG.json追記（何を誰に共有したか）
```

#### トポロジー6: ドキュメント同期 (context-sync)

```
Required Context:
  - docs/全ファイルのメタデータ（ファイル名+更新日のみ。全文は読まない）
  - state/STATUS.json
  Token Budget: 〜2,000トークン（メタデータのみ。詳細は段階的に読む）
      ↓
実行: 更新日チェック → 古いファイル特定 → 該当ファイルのみ全文Read → 矛盾検出
      ↓
FB-Computational:
  - 最終更新日が30日以上前のファイル検出
  - IMPROVEMENTS.json件数チェック（5件超なら context-review を促す）
      ↓
Post: 修正提案をユーザーに提示（自動修正はしない）
```

### 4.3 Required Context（FFの強制化）

レビュー指摘: rulesに「読め」と書くだけではLLMが忘れる。各スキルのSKILL.mdに強制読み込みリストを定義する。

```markdown
# SKILL.md テンプレート

## Required Context
以下のファイルをスキル実行開始時に必ずReadする:
- state/STATUS.json
- docs/STAKEHOLDER.md
（スキルごとに異なる）

## Token Budget
このスキルで読み込むコンテキストの上限: X,000トークン
```

これにより、FFがrules指示（Inferential）ではなくスキル構造（Computational寄り）で保証される。

---

## 5. Cross-Model Review（Codex統合）

### 5.1 設計思想

異なるモデルで同じ成果物をレビューし、単一モデルの盲点を補う。
Böckelerの「Inferential Feedback Sensor」の中で最も信頼性が高い。

### 5.2 cross-review スキル

```markdown
# cross-review SKILL.md

## Required Context
- workspace/ の最新成果物（レビュー対象）

## トリガー
「レビューして」「Codexに見てもらって」「セカンドオピニオン」

## 前提条件
- Codex CLI（`npm install -g @openai/codex`）がインストール済みであること
- `codex login` で認証済みであること

## フォールバック
Codex CLIが利用できない場合:
- Claude subagent（Agent tool）で独立レビューを実行
- メインコンテキストとは分離された視点でレビュー

## 実行フロー
1. workspace/ の最新成果物を特定
2. Codex CLI利用可能ならcodex exec、不可ならAgent toolでsubagent起動
3. レビュー結果をユーザーに提示
4. 修正が必要ならユーザー承認後に修正

## 使い分け（コスト vs 品質）
- risk-check → recommended（リスクの見落としは致命的）
- stakeholder-update → recommended（外部向けは品質重要）
- daily-report → optional（毎日やるとコスト高い）
- meeting-import → optional
- wbs-update → not needed（Computational FBで十分）
```

### 5.3 2x2マトリクスにおける位置づけ（Böckeler）

```
              │ Feedforward（事前）    │ Feedback（事後）
━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━
Computational │ Required Context      │ validate-state.sh
（決定論的）   │ JSONスキーマ           │ 必須セクションチェック
              │ テンプレート構造       │ 依存関係循環検出
              │                       │ approval-gate.sh
━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━
Inferential   │ rules/（行動原則）     │ LLMセルフチェック（将来追加）
（LLM推論）    │ skills/（ワークフロー）│ ★ Cross-Model Review
              │ docs/（知識）         │ context-sync矛盾検出
```

Computational（決定論的）が最も強い制御。まずComputationalを充実させ、Inferentialは段階的に追加。

---

## 6. 3層フィードバック + ステアリングループ

加賀谷氏（Asterminds）のSelf-improve 4層構造を参考に、PM業務向けに再設計。
Agent SDKは自動フィードバックの2箇所（project-advisor-llm, self-improve）のみで使用。

### 6.1 3層の全体像

```
SessionEnd hook
  │
  ├── Layer 1: project-advisor-rules.sh   毎回、shell、〜100ms
  │   「数字で検出できるプロジェクトの危険信号」
  │
  ├── Layer 2: project-advisor-llm.ts     日次、Agent SDK(Sonnet)、〜$0.05/回
  │   「文脈を読まないと分からないプロジェクトの危険信号」
  │
  └── Layer 3: self-improve.ts            週次、Agent SDK(Sonnet)、〜$0.10/回
      「ハーネス自体（rules/skills/hooks）の改善提案」
```

| 層 | 頻度 | コスト | 検出対象 | 出力先 |
|---|---|---|---|---|
| **L1: ルールベースFB** | 毎セッション | ゼロ | 期限超過、未対応リスク、未共有期間 | state/ALERTS.json (rule_alerts) |
| **L2: LLMプロジェクトFB** | 日次（24h経過時） | 〜$0.05 | 意思決定矛盾、見積もり甘さ、コミュニケーション懸念 | state/ALERTS.json (llm_alerts) |
| **L3: ハーネス自己改善** | 週次（10件+3日 or 20件強制） | 〜$0.10 | skills改善、rules追加、routing修正 | state/REVIEW_PROPOSALS.json |

### 6.2 Layer 1: project-advisor-rules.sh（毎回、決定論的）

```bash
#!/bin/bash
# SessionEnd で毎回発火。決定論的チェックのみ（LLM不使用、高速）
set -e
CWD="${CLAUDE_CWD:-.}"

python3 -c "
import json, os
from datetime import datetime, timedelta

alerts = []
now = datetime.now()

# 1. 期限超過タスク検出
wbs = '$CWD/state/WBS.json'
if os.path.exists(wbs):
    tasks = json.load(open(wbs)).get('tasks', [])
    for t in tasks:
        if t.get('due') and t.get('status') != 'done':
            try:
                due = datetime.fromisoformat(t['due'])
                if due < now:
                    days = (now - due).days
                    alerts.append({
                        'type': 'overdue_task',
                        'severity': 'high' if days > 7 else 'medium',
                        'message': f\"タスク '{t.get('name')}' が{days}日超過\"
                    })
            except: pass

# 2. 対応策未定の高リスク
risk = '$CWD/state/RISK.json'
if os.path.exists(risk):
    risks = json.load(open(risk)).get('risks', [])
    for r in risks:
        if not r.get('mitigation') and r.get('impact') == 'high':
            alerts.append({
                'type': 'unmitigated_risk',
                'severity': 'high',
                'message': f\"高リスク '{r.get('name')}' の対応策が未定義\"
            })
        if r.get('updated'):
            try:
                if (now - datetime.fromisoformat(r['updated'])).days > 30:
                    alerts.append({
                        'type': 'stale_risk',
                        'severity': 'medium',
                        'message': f\"リスク '{r.get('name')}' が30日以上未更新\"
                    })
            except: pass

# 3. ステークホルダーへの長期未共有
cl = '$CWD/state/CHANGELOG.json'
if os.path.exists(cl):
    entries = json.load(open(cl)).get('entries', [])
    sh_entries = [e for e in entries if e.get('type') == 'stakeholder_update']
    if sh_entries:
        try:
            last = datetime.fromisoformat(sh_entries[-1]['date'])
            gap = (now - last).days
            if gap > 14:
                alerts.append({
                    'type': 'stale_communication',
                    'severity': 'medium',
                    'message': f'ステークホルダーへの共有が{gap}日間なし'
                })
        except: pass

# 書き出し（既存のllm_alertsは保持）
alerts_path = '$CWD/state/ALERTS.json'
existing = {}
if os.path.exists(alerts_path):
    try: existing = json.load(open(alerts_path))
    except: pass

existing['rule_alerts'] = alerts
existing['rule_checked'] = now.isoformat()

with open(alerts_path, 'w') as f:
    json.dump(existing, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true
```

### 6.3 Layer 2: project-advisor-llm.ts（日次、Agent SDK）

発火条件: 前回LLMチェックから24時間以上経過。

```typescript
import { query } from "@anthropic-ai/claude-code";

async function dailyProjectReview() {
  const result = await query({
    prompt: `
あなたはプロジェクトアドバイザー。以下を読んで、PMが見落としている
危険信号や改善機会を指摘してください。

読むべきファイル:
1. state/STATUS.json（現在状態）
2. state/RISK.json（リスク台帳）
3. state/WBS.json（スケジュール）
4. state/CHANGELOG.json（直近10件の意思決定）
5. state/SESSION_LOG.json（直近5セッション）

観点:
- 意思決定間の矛盾はないか
- リスクの評価は妥当か（過小/過大評価）
- スケジュールの現実性（このペースで間に合うか）
- コミュニケーション上の懸念（共有漏れ、根回し不足）
- 「やるべきだがやっていないこと」

出力: state/ALERTS.jsonのllm_alertsフィールドにJSON配列で書き出し。
各アラート: {type, severity(high/medium/low), message, reasoning}
高確信のものだけ出力。「かもしれない」レベルは出さない。
llm_checkedフィールドも現在時刻で更新する。
    `,
    options: {
      cwd: process.cwd(),
      allowedTools: ["Read", "Write"],
      permissionMode: "acceptEdits",
      model: "sonnet",
      maxTurns: 5,
    }
  });
}

dailyProjectReview();
```

### 6.4 Layer 3: self-improve.ts（週次、Agent SDK）

発火条件: (IMPROVEMENTS.json 10件以上 AND 前回実行から3日以上) OR 20件以上（強制）。

加賀谷氏のSelf-improve構造に対応:
- **check**: rules/skills/の整合性を決定論的にチェック
- **entropy**: docs/ ↔ state/の矛盾をLLM意味解析で検出
- **feedback-loop**: IMPROVEMENTS.json分析 → 改善提案生成

```typescript
import { query } from "@anthropic-ai/claude-code";
import { execSync } from "child_process";

async function selfImprove() {
  // Phase 1: check（決定論的、高速）
  const checkIssues: string[] = [];
  
  // context-routingの参照先が全て存在するか
  // anti-patterns.mdが10件超でないか
  // skills/のRequired Contextの参照先が存在するか
  // （shell scriptで実行）

  // Phase 2: entropy + feedback-loop（LLM推論）
  const result = await query({
    prompt: `
あなたはハーネスエンジニア。PM Harnessの改善提案を行ってください。

読むべきファイル:
1. state/IMPROVEMENTS.json（蓄積された改善提案）
2. state/SESSION_LOG.json（直近のセッション履歴）
3. .claude/rules/ 配下の全ファイル
4. .claude/skills/ 配下の各SKILL.md

分析:
- IMPROVEMENTS.jsonの頻出パターンを特定
- rules/の不要ルール（3ヶ月未発火）を特定
- skills/のRequired Contextに追加すべきファイルがないか
- context-routingのポインタ表に不足がないか

出力: state/REVIEW_PROPOSALS.jsonに以下の形式で書き出し:
{
  "proposals": [
    {"target": "変更対象", "action": "追加/修正/削除", "reason": "根拠", "priority": "high/medium/low"}
  ],
  "last_run": "ISO 8601",
  "improvements_processed": 処理したIMPROVEMENTS件数
}
全変更はユーザー承認後に適用。自律的に書き換えてはいけない。
    `,
    options: {
      cwd: process.cwd(),
      allowedTools: ["Read", "Write"],
      permissionMode: "acceptEdits",
      model: "sonnet",
      maxTurns: 8,
    }
  });
}

selfImprove();
```

### 6.5 session-end.shの統合（発火制御）

```bash
#!/bin/bash
# SessionEnd で発火。3層のFBを条件付きで起動
set -e
CWD="${CLAUDE_CWD:-.}"

# --- SESSION_LOG追記 ---
python3 -c "
import json, datetime, os
log_path = '$CWD/state/SESSION_LOG.json'
try: log = json.load(open(log_path)) if os.path.exists(log_path) else {'sessions': []}
except: log = {'sessions': []}
log['sessions'].append({'timestamp': datetime.datetime.now().isoformat()})
if len(log['sessions']) > 100: log['sessions'] = log['sessions'][-100:]
with open(log_path, 'w') as f: json.dump(log, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true

# --- Layer 1: ルールベースFB（毎回） ---
bash "$CWD/.claude/hooks/project-advisor-rules.sh" 2>/dev/null || true

# --- Layer 2: LLMプロジェクトFB（日次: 24h経過時のみ） ---
LLM_HOURS=$(python3 -c "
import json,os
from datetime import datetime
f='$CWD/state/ALERTS.json'
if os.path.exists(f):
    ts=json.load(open(f)).get('llm_checked','2000-01-01T00:00:00')
    print(int((datetime.now()-datetime.fromisoformat(ts)).total_seconds()/3600))
else: print(999)
" 2>/dev/null || echo "999")

if [ "$LLM_HOURS" -ge 24 ]; then
  npx ts-node "$CWD/.claude/hooks/project-advisor-llm.ts" &
fi

# --- Layer 3: ハーネス自己改善（週次: 10件+3日 or 20件強制） ---
ITEMS=$(python3 -c "
import json,os
f='$CWD/state/IMPROVEMENTS.json'
print(len(json.load(open(f)).get('items',[]))) if os.path.exists(f) else print(0)
" 2>/dev/null || echo "0")

LAST_DAYS=$(python3 -c "
import json,os
from datetime import datetime
f='$CWD/state/REVIEW_PROPOSALS.json'
if os.path.exists(f):
    ts=json.load(open(f)).get('last_run','2000-01-01')
    print((datetime.now()-datetime.fromisoformat(ts)).days)
else: print(999)
" 2>/dev/null || echo "999")

if [ "$ITEMS" -ge 20 ] || ([ "$ITEMS" -ge 10 ] && [ "$LAST_DAYS" -ge 3 ]); then
  npx ts-node "$CWD/.claude/hooks/self-improve.ts" &
fi
```

### 6.6 session-start.shのALERTS表示追加

```bash
#!/bin/bash
# SessionStart で発火
set -e
CWD="${CLAUDE_CWD:-.}"

# STATUS.json要約
# （既存の§3.3と同じ）

# ALERTS表示
ALERTS="$CWD/state/ALERTS.json"
if [ -f "$ALERTS" ]; then
  python3 -c "
import json
a = json.load(open('$ALERTS'))
rules = a.get('rule_alerts', [])
llms = a.get('llm_alerts', [])
if rules or llms:
    print()
    print('## Alerts')
    for r in rules:
        sev = '🔴' if r['severity'] == 'high' else '🟡'
        print(f\"  {sev} [rule] {r['message']}\")
    for l in llms:
        sev = '🔴' if l['severity'] == 'high' else '🟡'
        print(f\"  {sev} [llm] {l['message']}\")
" 2>/dev/null || true
fi

# REVIEW_PROPOSALS表示
PROPOSALS="$CWD/state/REVIEW_PROPOSALS.json"
if [ -f "$PROPOSALS" ]; then
  python3 -c "
import json
p = json.load(open('$PROPOSALS'))
props = p.get('proposals', [])
if props:
    print()
    print(f'## Harness Improvement Proposals ({len(props)}件)')
    print('context-reviewを実行して適用してください')
" 2>/dev/null || true
fi
```

### 6.7 context-review スキル（手動起動 or /schedule）

REVIEW_PROPOSALS.jsonに基づいてハーネス改善を実行。全変更はユーザー承認必須。

### 6.8 剪定ルール

anti-patterns.mdが10件を超えたらcontext-reviewで剪定する:
- 3ヶ月間発火していないルール → 削除候補
- モデルのアップデートで不要になったルール → 削除
- 複数ルールを統合できるもの → 統合

### 6.9 SESSION_LOGのローテーション

SESSION_LOG.jsonは最新100件のみ保持。session-end.shで自動ローテーション。

### 6.10 投資判断（加賀谷氏のフレームワーク準拠）

| 消えるもの（3-6ヶ月寿命） | 残るもの（長期投資対象） |
|---|---|
| Compaction workaround | ワークフロー定義（skills） |
| Context resets | ドメイン知識（docs/state/） |
| 特定モデル向けプロンプトハック | 評価の仕組み（FB sensor） |
| | **自己改善ループ（3層FB）** |

---

## 7. プロジェクトタイプ別プリセット

### 7.1 3つのプリセット

#### Personal（日常・個人）

```
docs/: PROJECT.md のみ
state/: STATUS.json のみ
skills: daily-report, context-review
hooks: session-start, session-end（最小限）
```

#### Consulting（コンサル・BPR・導入支援）

```
docs/: PROJECT.md, STAKEHOLDER.md, COMMUNICATION.md
state/: STATUS.json, RISK.json, WBS.json, CHANGELOG.json, IMPROVEMENTS.json, SESSION_LOG.json
skills: 全スキル有効
hooks: 全hook有効
```

#### System Dev（システム開発）

```
docs/: Consulting全部 + SPEC.md
state/: Consulting全部 + BACKLOG.json
skills: 全スキル有効 + GitHub連携
hooks: 全hook有効
```

### 7.2 project-initフロー

```
ユーザー: 「新しいプロジェクトを始めたい」
  │
  ▼
project-init スキル発火
  │
  ├── Step 1: ヒアリング
  │   ├── プロジェクト名
  │   ├── どんなプロジェクト？ → タイプ自動判定
  │   ├── ゴール
  │   ├── 関係者（consulting/system_devのみ）
  │   └── 期限（consulting/system_devのみ）
  │
  ├── Step 2: ディレクトリ生成
  │   ├── タイプに応じたテンプレートから生成
  │   ├── CLAUDE.md（project_type記載）
  │   └── .claude/ 配下のrules/hooks/skills/settings.json配置
  │
  ├── Step 3: 初期コンテキスト投入
  │   ├── ヒアリング内容をdocs/state/に記入
  │   └── WBS初期マイルストーン（consulting/system_devのみ）
  │
  └── Step 4: 確認
      ├── 生成結果をユーザーに提示
      └── 承認後に完了
```

---

## 8. CLAUDE.md（司令塔）

```markdown
# Project: {project_name}

project_type: {personal|consulting|system_dev}

## PM Harness
- rules: .claude/rules/ （行動原則 + ルーティング + anti-patterns）
- hooks: .claude/hooks/ （セッション管理 + バリデーション + 承認ゲート）
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
```

---

## 9. 設計原則まとめ

### やること

| 原則 | 実装 |
|---|---|
| Thin rules | 60行以下。知識はdocs/に、状態はstate/に |
| JIT読み込み | Required Context + context-routingのポインタ表 |
| トポロジー限定 | 6パターンに絞り各々にFF+FBペア |
| JSON for state | state/はJSON。Markdownより壊れにくい |
| Success is silent | 正常時はstate更新のみ。異常時だけ詳細報告 |
| Failure-to-Rule変換 | ミス → IMPROVEMENTS.json → anti-patterns.md |
| Computational First | まずComputational FBで固め、Inferentialは段階的に追加 |
| 3層フィードバック | L1ルールベース(毎回) + L2 LLM(日次) + L3ハーネス改善(週次) |
| Cross-Model Review | 重要な成果物はCodex or subagentでセカンドオピニオン |
| Human approval gate | state/docs/変更はPreToolUse hookでログ。ステアリング変更は人間承認必須 |
| Token Budget | 1スキル実行あたり10,000トークン以内 |
| Agent SDK限定利用 | 自動FB（project-advisor-llm, self-improve）のみ。日常スキルはClaude Code native |

### やらないこと

| アンチパターン | 理由 |
|---|---|
| rulesに知識を書く | コンテキスト肥大化。JIT読み込みで代替 |
| @参照を使う | 遅延読込ではなく即時全読込される |
| 存在しないhookに依存 | PreCompact/PostCompact/SubagentStopは存在しない |
| Stopで改善蓄積 | 応答ごとに発火し頻度が高すぎる。SessionEndを使う |
| 自律的ルール書き換え | 暴走リスク。人間レビューゲート必須 |
| 全FB層を同時に実装 | Computationalから始めて段階的に拡張 |
| context-syncで全文読み | メタデータ→段階的読み込みでToken Budget内に |

---

## 10. レビュー履歴

### v2.0 対応済み指摘（独立レビューより）

| 指摘 | 深刻度 | 対応 |
|---|---|---|
| PreCompact/PostCompact hookが存在しない | HIGH | 削除。rules指示で代替（§3.8） |
| HANDOFF.jsonのactive_taskが常にNull | HIGH | 削除。STATUS.jsonのcurrent_taskフィールドで代替 |
| 承認ゲートが形骸化する | HIGH | PreToolUse hookでapproval-gate.sh追加（§3.4） |
| FFが指示に依存しすぎ | HIGH | Required Contextセクションをスキルに追加（§4.3） |
| Token Budget未設計 | HIGH | 10,000トークン/スキル上限を設定（§2.1, §4.2） |
| CHANGELOG.mdはJSONが適切 | MEDIUM | state/CHANGELOG.jsonに移動 |
| Steering Loopが手動依存 | MEDIUM | context-syncにリマインダー機構追加（§6.1） |
| validate-state.shのエラーハンドリング | MEDIUM | stdin解析+ファイルパスフィルタ+exit 2で改善（§3.6） |
| SESSION_LOG肥大化 | MEDIUM | 100件ローテーション追加（§6.3） |
| Codexフォールバック未定義 | MEDIUM | subagent代替を明記（§5.2） |
| 課題管理トポロジー欠落 | MEDIUM | 外部管理（Notion/GitHub Issues）と明記（§4.1） |

### 未対応（将来検討）

| 指摘 | 深刻度 | 理由 |
|---|---|---|
| 並行セッションの競合 | MEDIUM | 個人PMユースケースでは低リスク。チーム利用時に対応 |
| Progressive Disclosureの深掘り | MEDIUM | Token Budgetで暫定対応。運用後に改善 |
| STAKEHOLDER.mdのJSON化 | LOW | 人間の可読性を優先し当面Markdown |
| 予算・コスト管理 | LOW | スコープ外として明記済み |

---

## 11. 出典

| 出典 | URL | 取り入れた要素 |
|---|---|---|
| Böckeler (Martin Fowler) | martinfowler.com/articles/harness-engineering.html | FF/FB、2x2マトリクス、Ashby、トポロジー |
| Anthropic | anthropic.com/engineering/effective-harnesses-for-long-running-agents | JSON>MD、Selective Reading、Two-Agent |
| Anthropic | code.claude.com/docs/en/best-practices | CLAUDE.md設計、@参照問題、Skills推奨 |
| Anthropic | code.claude.com/docs/en/hooks | Hooks API仕様（実機確認に使用） |
| Osmani | addyosmani.com/blog/agent-harness-engineering/ | 60行、Silent success、Progressive Disclosure |
| Hashimoto | mitchellh.com/writing/my-ai-adoption-journey | Failure-to-Rule、ハーネス命名の起源 |
| Asterminds (加賀谷) | Findy Harness Engineering入門 2026-04-22 | Cross-Model Review、Self-improve |
| すぅ | note.com | CLAUDE.md司令塔、docs/構成、hooks改善蓄積 |
| miyatti (ai-plc) | github.com/miyatti777/ai-plc | install.sh、タイプ別適応、project-init |
| Stanford Meta-Harness | arXiv:2603.28052 | 同一モデルでハーネス違い6倍差 |
| Google DeepMind AutoHarness | arXiv:2603.03329 | ハーネス自動合成 |
