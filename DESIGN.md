# PM Harness Design — Claude Code Harness Engineering for Project Management

## 0. Overview

PM業務をClaude Code nativeで行うためのハーネス設計。
Agent SDKやコードは使わず、markdown + shell script + JSONのみで構成する。

### 設計根拠

| 出典 | 取り入れた原則 |
|---|---|
| Böckeler (Martin Fowler) | FF/FBペア設計、Ashbyの法則によるトポロジー限定、Computational > Inferential |
| Anthropic公式 | JSON > Markdown（状態管理）、Selective Reading、10,000文字上限、@参照の即時読込問題 |
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
│   │   ├── session-start.sh                 STATUS.json要約注入
│   │   ├── session-resume.sh                ハンドオフ復元
│   │   ├── pre-compact.sh                   ハンドオフファイル生成
│   │   ├── post-compact.sh                  状態復元注入
│   │   ├── session-end.sh                   SESSION_LOG + IMPROVEMENTS蓄積
│   │   └── validate-state.sh                state/*.jsonバリデーション
│   └── skills/
│       ├── project-init/                    プロジェクト初期設定
│       ├── daily-report/                    日報生成
│       ├── meeting-import/                  議事録取り込み
│       ├── wbs-update/                      WBS管理
│       ├── risk-check/                      リスク管理
│       ├── stakeholder-update/              ステークホルダー通知
│       ├── context-sync/                    ドキュメント同期+矛盾検出
│       ├── context-review/                  ステアリング: 改善レビュー
│       └── cross-review/                    Cross-Model Review（Codex）
└── templates/
    ├── personal/
    │   ├── docs/
    │   └── state/
    ├── consulting/
    │   ├── docs/
    │   └── state/
    └── system_dev/
        ├── docs/
        └── state/
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
│   ├── hooks/                           ← 6つのライフサイクルhook
│   │   ├── session-start.sh
│   │   ├── session-resume.sh
│   │   ├── pre-compact.sh
│   │   ├── post-compact.sh
│   │   ├── session-end.sh
│   │   └── validate-state.sh
│   ├── skills/                          ← PM特化スキル群
│   │   └── (上記と同じ)
│   └── settings.json
├── docs/                                ← 人間向けMarkdown（外部共有可能）
│   ├── PROJECT.md
│   ├── STAKEHOLDER.md
│   ├── COMMUNICATION.md
│   └── CHANGELOG.md
├── state/                               ← AI向けJSON（構造化データ）
│   ├── STATUS.json
│   ├── RISK.json
│   ├── WBS.json
│   ├── IMPROVEMENTS.json
│   ├── SESSION_LOG.json
│   └── HANDOFF.json
├── meeting/                             ← 議事録
└── workspace/                           ← 作業領域
```

### 1.3 docs/ と state/ の分離原則

| | docs/ | state/ |
|---|---|---|
| 形式 | Markdown | JSON |
| 読者 | 人間 + AI | AIのみ |
| 外部共有 | Notion/Google Drive等に同期可 | 同期しない |
| 書き換えリスク | 高い（Markdownは意図しない上書きが起きやすい） | 低い（Anthropic: JSONの方が壊れにくい） |
| 内容 | 知識・方針・ルール | 状態・進捗・構造化データ |

---

## 2. Rules設計（60行以下）

ハーネスの肥大化を防ぐ最重要ポイント。
rulesは全セッションで自動ロードされるため、ここに知識を入れてはいけない。

### 2.1 01-pm-behavior.md（行動原則 〜20行）

```markdown
# PM行動原則

- PMとして振る舞う。成果物の品質とプロジェクト成功を最優先する
- 意思決定はユーザーに委ねる。提案は出すが勝手に決めない
- 不確実性がある場合は必ず明示する
- docs/やstate/を更新する際は必ず変更内容を提示して承認を得る
- スキル実行後、docs/state/に更新すべき情報がないか確認する
- 改善すべき点を見つけたら、直接修正せずIMPROVEMENTS.jsonに記録する
- 成功時は静かに、異常検出時は詳しく報告する（Success is silent）
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
| 意思決定の経緯 | docs/CHANGELOG.md |
| プロジェクト概要 | docs/PROJECT.md |
| 改善レビュー | state/IMPROVEMENTS.json + state/SESSION_LOG.json |
```

### 2.3 03-anti-patterns.md（やらかし記録 〜20行）

```markdown
# Anti-Patterns

各エントリは「日付・インシデント・対策」を必ず含む。
トレースできないルールはノイズ（Osmani: "trace to specific past failures"）。
10件を超えたらcontext-reviewで剪定する。

（初期状態は空。ステアリングループで育つ）
```

---

## 3. Hooks設計

### 3.1 ライフサイクルと発火タイミング

```
SessionStart(startup)    ← 新セッション開始
  │                         → session-start.sh: STATUS.json要約注入
  ▼
SessionStart(resume)     ← 再開 or compaction後
  │                         → session-resume.sh: HANDOFF.json復元
  ▼
(作業中)
  │
PostToolUse(Edit|Write)  ← state/*.json編集時
  │                         → validate-state.sh: JSONスキーマ検証
  ▼
PreCompact               ← compaction直前
  │                         → pre-compact.sh: HANDOFF.json生成
  ▼
PostCompact              ← compaction直後
  │                         → post-compact.sh: 状態復元注入
  ▼
SessionEnd               ← セッション終了時
                            → session-end.sh: SESSION_LOG追記 + IMPROVEMENTS蓄積
```

重要: `Stop`（応答完了）と`SessionEnd`（セッション終了）は異なる。
改善蓄積はSessionEndで行う（Stopは応答ごとに発火し頻度が高すぎる）。

### 3.2 session-start.sh

```bash
#!/bin/bash
# SessionStart(startup) で発火
# STATUS.jsonから3,000文字以内の要約を注入（上限10,000文字のバッファ確保）
if [ -f state/STATUS.json ]; then
  python3 -c "
import json, sys
with open('state/STATUS.json') as f:
    s = json.load(f)
print('## Current Status')
print(f\"Project: {s.get('project_name', 'N/A')}\")
print(f\"Phase: {s.get('current_phase', 'N/A')}\")
print(f\"Updated: {s.get('last_updated', 'N/A')}\")
if s.get('blockers'):
    print('Blockers: ' + ', '.join(s['blockers']))
if s.get('next_actions'):
    print('Next: ' + ', '.join(s['next_actions'][:3]))
"
fi
```

### 3.3 pre-compact.sh / post-compact.sh

```bash
#!/bin/bash
# PreCompact: 現在の作業状態をHANDOFF.jsonに保存
python3 -c "
import json, datetime
handoff = {
    'timestamp': datetime.datetime.now().isoformat(),
    'status_snapshot': json.load(open('state/STATUS.json')) if __import__('os').path.exists('state/STATUS.json') else {},
    'active_task': None,  # 現在進行中のタスク
    'context_notes': ''   # セッション中の重要メモ
}
with open('state/HANDOFF.json', 'w') as f:
    json.dump(handoff, f, ensure_ascii=False, indent=2)
"
```

### 3.4 session-end.sh

```bash
#!/bin/bash
# SessionEnd: SESSION_LOGに行動記録を追記
python3 -c "
import json, datetime, os
log_path = 'state/SESSION_LOG.json'
log = json.load(open(log_path)) if os.path.exists(log_path) else {'sessions': []}
log['sessions'].append({
    'timestamp': datetime.datetime.now().isoformat(),
    'end_reason': os.environ.get('END_REASON', 'unknown')
})
with open(log_path, 'w') as f:
    json.dump(log, f, ensure_ascii=False, indent=2)
"
```

### 3.5 validate-state.sh

```bash
#!/bin/bash
# PostToolUse(Edit|Write): state/*.jsonの整合性チェック
for f in state/*.json; do
  python3 -c "import json; json.load(open('$f'))" 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: $f is invalid JSON"
  fi
done
```

### 3.6 settings.json（hooks登録）

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-start.sh"}]
      },
      {
        "matcher": "resume|compact|clear",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-resume.sh"}]
      }
    ],
    "PreCompact": [
      {
        "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-compact.sh"}]
      }
    ],
    "PostCompact": [
      {
        "hooks": [{"type": "command", "command": "bash .claude/hooks/post-compact.sh"}]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [{"type": "command", "command": "bash .claude/hooks/session-end.sh"}]
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

---

## 4. 6トポロジー × FF/FBペア設計

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
| 6 | ドキュメント同期 | context-sync | docs/ + state/全体 | 矛盾修正 + 更新 |

### 4.2 FF/FBペア詳細

各スキルは「FF（事前ガイド）→ 実行 → FB（事後センサー）」の3フェーズで構成する。

#### トポロジー1: 日報 (daily-report)

```
FF: docs/COMMUNICATION.md（報告ルール）
    state/STATUS.json（現在状態）
    Slackチャンネル一覧
      ↓
実行: Slack MCPから情報収集 → 日報生成
      ↓
FB-Computational: 必須セクション存在チェック（進捗/決定事項/リスク/明日の予定）
                  Slackチャンネル網羅率チェック
FB-Inferential:   前日との差分で重要変更の見落としがないか（LLMセルフチェック）
FB-CrossModel:    Codexで日報品質レビュー（optional）
      ↓
Post: state/STATUS.json更新、CHANGELOG.md追記（重要決定があれば）
```

#### トポロジー2: 議事録 (meeting-import)

```
FF: docs/STAKEHOLDER.md（参加者情報）
    会議テンプレート
      ↓
実行: 文字起こしファイル → 議事録生成 → 決定事項・TODO抽出
      ↓
FB-Computational: 決定事項とTODOの存在チェック
                  TODO担当者がSTAKEHOLDER.mdに存在するか
FB-Inferential:   前回議事録との整合性チェック（矛盾する決定がないか）
FB-CrossModel:    Codexで網羅性レビュー（optional）
      ↓
Post: state/STATUS.json更新、docs/CHANGELOG.md追記
```

#### トポロジー3: WBS管理 (wbs-update)

```
FF: docs/PROJECT.md（スコープ）
    state/WBS.json（現在のWBS）
    state/STATUS.json（進捗状態）
      ↓
実行: 進捗情報を反映 → WBS更新 → マイルストーン確認
      ↓
FB-Computational: 依存関係の循環検出
                  期限超過タスクの自動検出
                  日付整合性（開始日 < 終了日）
FB-Inferential:   マイルストーン超過リスクの評価
      ↓
Post: state/STATUS.json更新（次フェーズ情報）
```

#### トポロジー4: リスク管理 (risk-check)

```
FF: docs/PROJECT.md（プロジェクト制約）
    state/RISK.json（既知リスク）
    state/WBS.json（スケジュール）
      ↓
実行: リスクの再評価 → 新規リスクの検出 → 対応策の確認
      ↓
FB-Computational: 対応策未定リスクの検出
                  リスク件数の急増検知（前回比）
                  直近N日間未更新リスクのアラート
FB-Inferential:   リスク評価の妥当性チェック（影響度×発生確率）
FB-CrossModel:    Codexでリスク評価の盲点チェック（recommended）
      ↓
Post: state/RISK.json更新
```

#### トポロジー5: ステークホルダー通知 (stakeholder-update)

```
FF: docs/STAKEHOLDER.md（宛先・役割）
    docs/COMMUNICATION.md（コミュニケーションルール）
    state/STATUS.json + state/RISK.json
      ↓
実行: 宛先別に要約生成 → Slack/メール向けフォーマット変換
      ↓
FB-Computational: 宛先の実在チェック
                  テンプレート準拠チェック
FB-Inferential:   トーン・詳細度が宛先の役割に適切か
FB-CrossModel:    Codexで「受け手視点」レビュー（recommended）
      ↓
Post: docs/CHANGELOG.md追記（何を誰に共有したか）
```

#### トポロジー6: ドキュメント同期 (context-sync)

```
FF: docs/全ファイル + state/全ファイル
      ↓
実行: docs/間の矛盾検出 → docs/ ↔ state/の整合性確認 → 最終更新日チェック
      ↓
FB-Computational: 最終更新日が30日以上前のファイル検出
                  docs/とstate/で矛盾するデータの検出
FB-Inferential:   docs/の記述とstate/のデータが意味的に矛盾していないか
      ↓
Post: 修正提案をユーザーに提示（自動修正はしない）
```

---

## 5. Cross-Model Review（Codex統合）

### 5.1 設計思想

Asterminds（加賀谷氏）のパイプライン:
```
factory(Sonnet+Opus) → Cross-Model Review(Codex) → Draft PR
```

異なるモデルで同じ成果物をレビューすることで、単一モデルの盲点を補う。
これはBöckelerの「Inferential Feedback Sensor」に該当する。

### 5.2 PM Harnessでの適用

```
Claude（スキル実行）→ 成果物生成 → Codex Review → 品質チェック結果
```

cross-reviewスキルとして実装し、任意のスキル実行後に呼び出せるようにする。

### 5.3 cross-review スキルの設計

```markdown
# cross-review SKILL.md

## トリガー
「レビューして」「Codexに見てもらって」「セカンドオピニオン」

## 実行フロー
1. workspace/ の最新成果物を特定
2. Codex CLIに以下を依頼:
   - 成果物の品質チェック（網羅性、整合性、盲点）
   - docs/との矛盾がないか
   - 受け手視点での問題点
3. Codexの指摘をユーザーに提示
4. 修正が必要ならユーザー承認後に修正

## 使い分け
- daily-report → optional（毎日やるとコスト高い）
- risk-check → recommended（リスクの見落としは致命的）
- stakeholder-update → recommended（外部向けは品質重要）
- meeting-import → optional
- wbs-update → not needed（Computational FBで十分）
```

### 5.4 2x2マトリクスにおける位置づけ（Böckeler）

```
              │ Feedforward（事前）    │ Feedback（事後）
━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━
Computational │ JSONスキーマ           │ validate-state.sh
（決定論的）   │ テンプレート構造       │ 必須セクションチェック
              │                       │ 依存関係循環検出
━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━
Inferential   │ rules/（行動原則）     │ LLMセルフチェック
（LLM推論）    │ skills/（ワークフロー）│ ★ Cross-Model Review
              │ docs/（知識）         │ context-sync矛盾検出
```

Computational（決定論的）が最も強い制御。
Cross-Model Reviewは Inferential Feedback の中で最も信頼性が高い（異なるモデルの視点）。

---

## 6. ステアリングループ（自己改善）

### 6.1 サイクル

```
タスク実行
  │
  ├── FB sensor が異常検出 → 即時修正 + IMPROVEMENTS.jsonに記録
  │
  ▼
SessionEnd hook
  │
  ├── SESSION_LOG.jsonに行動記録を追記
  ├── IMPROVEMENTS.jsonに改善提案を蓄積
  │   - 「このスキルのFFが不足していた」
  │   - 「このFBセンサーが検出できなかった問題があった」
  │   - 「anti-patternsに追加すべきインシデント」
  │
  ▼
context-review スキル（定期的に手動起動）
  │
  ├── IMPROVEMENTS.jsonを読む
  ├── SESSION_LOG.jsonでパターン分析
  ├── 頻出問題 → rules/03-anti-patterns.md に昇格
  ├── スキルの改善提案 → 該当スキルを修正
  ├── 不要になったrule → 削除（肥大化防止）
  └── ★ 全変更はユーザー承認後に適用（自律的ルール書き換えはしない）
```

### 6.2 Hashimotoの原則

> "Each line in AGENTS.md should correspond to a specific past bad behavior."

anti-patterns.mdの各エントリは、具体的なインシデントにトレースできなければならない。
「なんとなく良さそう」で追加したルールはノイズになる。

### 6.3 剪定ルール

anti-patterns.mdが10件を超えたらcontext-reviewで剪定する:
- 3ヶ月間発火していないルール → 削除候補
- モデルのアップデートで不要になったルール → 削除
- 複数ルールを統合できるもの → 統合

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
docs/: PROJECT.md, STAKEHOLDER.md, COMMUNICATION.md, CHANGELOG.md
state/: STATUS.json, RISK.json, WBS.json, IMPROVEMENTS.json, SESSION_LOG.json
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
  │   └── .claude/ 配下のrules/hooks/skills配置
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
- hooks: .claude/hooks/ （セッション管理 + バリデーション）
- skills: .claude/skills/ （PMワークフロー）
- docs: docs/ （人間向け知識、JIT読み込み）
- state: state/ （AI向け構造化データ、JIT読み込み）

## Working Directory
作業はworkspace/で行う。成果物もここに格納。
議事録はmeeting/に格納。

## Key Constraints
- docs/state/の更新は必ずユーザー承認を得る
- rulesは60行以下を維持する
- @参照は使わない（即時全読込されるため）
```

---

## 9. 設計原則まとめ

### やること

| 原則 | 実装 |
|---|---|
| Thin rules | 60行以下。知識はdocs/に、状態はstate/に |
| JIT読み込み | context-routingのポインタ表でスキルがReadする |
| トポロジー限定 | 6パターンに絞り各々にFF+FBペア |
| JSON for state | state/はJSON。Markdownより壊れにくい |
| Success is silent | 正常時はstate更新のみ。異常時だけ詳細報告 |
| Failure-to-Rule変換 | ミス → IMPROVEMENTS.json → anti-patterns.md |
| Cross-Model Review | 重要な成果物はCodexでセカンドオピニオン |
| Human approval gate | ステアリングの変更適用は必ず人間が承認 |

### やらないこと

| アンチパターン | 理由 |
|---|---|
| rulesに知識を書く | コンテキスト肥大化。JIT読み込みで代替 |
| @参照を使う | 遅延読込ではなく即時全読込される |
| Stopで改善蓄積 | 応答ごとに発火し頻度が高すぎる。SessionEndを使う |
| 自律的ルール書き換え | 暴走リスク。人間レビューゲート必須 |
| 4ステージパイプライン | PM業務には重すぎる。トポロジー単位で十分 |
| ルール数千行 | 1000行超で指示の半分が無視される |

---

## 10. 出典

| 出典 | URL | 取り入れた要素 |
|---|---|---|
| Böckeler (Martin Fowler) | martinfowler.com/articles/harness-engineering.html | FF/FB、2x2マトリクス、Ashby、トポロジー |
| Anthropic | anthropic.com/engineering/effective-harnesses-for-long-running-agents | JSON>MD、Selective Reading、Two-Agent |
| Anthropic | code.claude.com/docs/en/best-practices | CLAUDE.md設計、@参照問題、Skills推奨 |
| Osmani | addyosmani.com/blog/agent-harness-engineering/ | 60行、Silent success、Progressive Disclosure |
| Hashimoto | mitchellh.com/writing/my-ai-adoption-journey | Failure-to-Rule、ハーネス命名の起源 |
| Asterminds (加賀谷) | Findy Harness Engineering入門 2026-04-22 | Cross-Model Review、Self-improve |
| すぅ | note.com | CLAUDE.md司令塔、docs/構成、hooks改善蓄積 |
| miyatti (ai-plc) | github.com/miyatti777/ai-plc | install.sh、タイプ別適応、project-init |
| Stanford Meta-Harness | arXiv:2603.28052 | 同一モデルでハーネス違い6倍差 |
| Google DeepMind AutoHarness | arXiv:2603.03329 | ハーネス自動合成 |
