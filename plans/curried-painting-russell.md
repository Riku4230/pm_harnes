# PM-Harness DESIGN.md v4.0 — 実装計画

## Context

PM業務をClaude Code + ハーネスエンジニアリングで体系化するプロジェクト。
DESIGN.md v3.0まで3回の改訂を経て、今回のCEOレビュー（SELECTIVE EXPANSION）で
4つの拡張が承認された。v4.0はこれらを統合した最終設計書。

### CEOレビュー決定事項

| # | 拡張 | 決定 |
|---|---|---|
| 1 | PM Principles（業務目的の言語化） | ✅ ACCEPTED |
| 2 | PM固有センサー群（Decision Drift, Open Questions Aging, Source-of-Truth） | ✅ ACCEPTED |
| 3 | スキル名変更（context-pack, draft-update） | ✅ ACCEPTED |
| 4 | 3層制御の体系を中心構造に | ✅ ACCEPTED |
| 5 | PM版Four Keys | 📋 DEFERRED |
| 6 | Assumption Ledger | 📋 DEFERRED |

---

## 実装計画: DESIGN.md v4.0 書き換え

### 変更するファイル
- `DESIGN.md` — 全面改訂

### 新しい構成（セクション構成）

```
§0   Overview（更新: 定義を追加）
§1   業務目的（★新規: PM Principles）
§2   3層制御の体系（★新規: ①そもそもさせない ②検知 ③改善）
§3   開発→PMの5つの違い（★新規）
§4   ディレクトリ構成（更新: スキル名変更反映）
§5   Rules設計（更新: 01をPM Principlesに）
§6   Hooks設計（更新: PM固有センサー追加）
§7   トポロジー × FF/FBペア（更新: context-pack, draft-update, センサー重症度）
§8   Cross-Model Review（変更なし）
§9   3層フィードバック + ステアリングループ（更新: PM固有センサーをL1/L2に配置）
§10  プロジェクトタイプ別プリセット（変更なし）
§11  CLAUDE.md（変更なし）
§12  設計原則まとめ（更新: 3層制御視点で再整理）
§13  レビュー履歴（更新: v4.0の変更を追記）
§14  出典（更新）
```

### 各セクションの具体的変更内容

#### §1 業務目的（新規追加）

```markdown
## 1. 業務目的

Gota氏の4ステップの最初。これがないとハーネスは「不安への反応」になる。

### 何を守るか
- 関係者との認識齟齬を最小化する
- 意思決定とその根拠を追跡可能にする
- リスクを早期検出し対応策を確保する
- プロジェクト知識をセッション間で保持する

### 何を守らないか
- 成果物のフォーマット美化（内容が正しければ良い）
- 全タスクの詳細追跡（Notion/GitHub Issuesに委譲）
- 予算・コスト管理（スコープ外）

### どこで人が介入するか
- 外部ステークホルダーへの送信前（AI→下書き→人間確認→送信）
- リスク対応の優先順位決定
- プロジェクトスコープの変更判断
- ハーネス自体の変更（ステアリングループの承認ゲート）
```

#### §2 3層制御の体系（新規追加）

```markdown
## 2. 3層制御の体系

強い ←────────────────────→ 弱い

①そもそもさせない   ②やった後に検知   ③仕組み自体を改善
 構造で違反を不可能に  事後チェック       ①②を育て続ける

### ① そもそもさせない（Computational Guide）
- JSONスキーマバリデーション（RISK.jsonのmitigation必須等）
- allowed-tools制限（draft-updateにSlack送信不許可）
- approval-gate.sh（docs/state/変更をPreToolUseで検知）
- Required Context（スキル発火時の強制読み込み）
- Token Budget（10,000トークン/スキル）
- CHANGELOG.jsonのappend-only制約

### ② やった後に検知する（Feedback Sensor）
3層で頻度とコストを分離:
- L1ルールベース（毎回、shell、コストゼロ）
- L2 LLMプロジェクトFB（日次、Agent SDK）
- Cross-Model Review（任意、Codex/subagent）

センサー重症度:
- Block: 期限なしlaunch、ownerなし重要タスク、source-of-truth矛盾
- Warn: 成功指標が弱い、ステークホルダー確認不明、open question古い
- Log: 表現の曖昧さ、フォーマット崩れ

### ③ 仕組み自体を改善する（Steering Loop）
- IMPROVEMENTS蓄積 → self-improve.ts（週次）→ REVIEW_PROPOSALS
- context-reviewで人間承認後に適用
- Verifyフェーズ: 適用後2週間、同種インシデント再発を監視
```

#### §3 開発→PMの5つの違い（新規追加）

```markdown
## 3. 開発→PMの5つの違い

1. 認識齟齬がPM最大のリスク（テストで検出不可）
2. デプロイ先が人間の頭（共有しないと価値ゼロ）
3. 成果物が曖昧（「正しいPRD」をバリデーションできない）
4. コンテキスト腐食が高速（日単位で変わる）
5. 外部送信は不可逆（git revertできない）
```

#### §4 ディレクトリ構成（スキル名変更）

変更箇所:
- `daily-report/` → `context-pack/`（情報収集。日報に限定しない）
- `stakeholder-update/` → `draft-update/`（下書きのみ。送信不可）
- state/にopen_questions[]追加検討

#### §6 Hooks設計（PM固有センサー追加）

project-advisor-rules.shに追加:
- **Decision Drift検出**: CHANGELOG.jsonの過去の決定と最新state/の矛盾をチェック
- **Open Questions Aging**: STATUS.jsonのopen_questions[]で3日以上owner不在、7日以上未解決を検出
- **Source-of-Truth Reconciliation**: docs/とstate/の日付・内容の不一致を検出

project-advisor-llm.ts（L2、日次）に追加:
- 意思決定間の意味的矛盾検出
- 「このペースだとマイルストーンに間に合わない」予測
- ステークホルダー間の認識ズレの兆候

#### §7 トポロジー（センサー重症度追加）

各トポロジーのFBセンサーにBlock/Warn/Log分類を追加。
context-packとdraft-updateの定義を記述。

---

## 実装手順

1. DESIGN.md全文をバックアップ（gitで管理済み）
2. §0-§14の新しい構成で全面書き換え
3. git commit

## 検証方法

- DESIGN.mdの行数確認（v3.0は約500行。v4.0は600-700行想定）
- rules合計行数が60行以下を維持
- 全セクションが3層制御の体系と整合しているか確認
- CEOレビューのAccepted 4件が全て反映されているか確認
- Deferred 2件がTODOsとして明記されているか確認
