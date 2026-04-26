# PM-Harness

**PM業務の周囲にある制御システム（AI-PMO）**

PM-Harnessは、Claude Code上で動くPM業務用のハーネス。
PMの代わりに判断するのではなく、**進捗遅れ・リスク放置・認識齟齬を自動検知し、PMの注意を重要箇所に向ける**。

人間のPMOが定例会議でやっていることを、hooksとAgent SDKで自動化した。

---

## 特徴

### 1. 「そもそもさせない」構造制約
- 高リスクに対応策なしで保存 → **JSONスキーマでブロック**
- AIが外部送信 → **allowed-toolsで構造的に不可能**
- 過去の意思決定を改ざん → **append-only制約でブロック**

### 2. 3層フィードバックで危険信号を自動検出
- **L1（毎セッション）**: 期限超過、未対応リスク、Decision Drift、Open Questions放置
- **L2（日次）**: 意思決定の矛盾、スケジュール予測、共有漏れ
- **L3（週次）**: ハーネス自体の改善提案

### 3. ハーネスが自分で育つ
ミスが発生 → IMPROVEMENTS.jsonに蓄積 → self-improve.tsが分析 → 改善提案 → PMが承認 → ハーネス改善

---

## クイックスタート

### インストール

```bash
# 新しいプロジェクトに導入
bash install.sh --target ~/my-project --type consulting
```

### セッション開始

```bash
cd ~/my-project
claude
```

セッションが始まると自動でプロジェクト状況が表示される:

```
## Current Status
Project: 引越しプロジェクト
Type: personal
Phase: 準備
Next: 不動産屋に連絡、荷物リスト作成

## Alerts
🔴 [rule] タスク'退去届提出'が3日超過
🟡 [rule] Open Question '引越し業者の選定基準' が5日間未回答
```

---

## 使い方の例: 引越しプロジェクト

「3ヶ月後に引越しする」という日常的なプロジェクトで、PM-Harnessがどう動くかを示す。

### Day 1: プロジェクト開始

```
あなた: 「引越しプロジェクトを始めたい」

PM-Harness (project-init):
  プロジェクト名は？ → 「引越し」
  どんなプロジェクト？ → personal と判定
  ゴールは？ → 「7月末までに新居に移る」
  
  → docs/PROJECT.md, state/STATUS.json が生成される
  → 「ゴールと期限を設定しました。次にやることをWBSに落としますか？」
```

### Day 1: タスク洗い出し

```
あなた: 「やること洗い出して」

PM-Harness (wbs-update):
  Required Context: state/WBS.json + state/STATUS.json を読み込み
  
  あなたと対話しながらタスクを整理:
  - 退去届提出（5/15まで）
  - 不動産屋に連絡（5/20まで）
  - 荷物リスト作成（6/1まで）
  - 引越し業者選定（6/15まで）
  - 梱包作業（7/1〜7/20）
  - 引越し当日（7/25）
  
  FB-Computational:
  ✓ 依存関係チェック OK
  ✓ 日付整合性 OK
  
  → state/WBS.json に保存
```

### Day 3: 情報収集

```
あなた: 「引越しについて調べた情報をまとめたい」

PM-Harness (context-pack):
  あなたが共有した情報を整理:
  - 不動産屋3社の比較
  - 引越し業者の相場感
  - 退去届の手続き方法
  
  → state/STATUS.json 更新
  → state/CHANGELOG.json に「不動産屋3社を比較検討中」を記録
```

### Day 7: セッション開始時の自動アラート

```
（1週間後にセッションを開始すると自動で表示される）

## Current Status
Project: 引越し / Phase: 準備

## Alerts
🔴 [rule] タスク'退去届提出'が3日超過
🟡 [rule] Open Question '引越し業者の選定基準' が5日間未回答
🟡 [llm] 退去届が遅れると違約金が発生するリスク。早急に対応を推奨
```

PMは自分で状況を確認しなくても、**セッションを開くだけで「今ヤバいこと」が分かる**。

### Day 7: リスク対応

```
あなた: 「リスクチェックして」

PM-Harness (risk-check):
  Required Context: state/RISK.json + state/WBS.json
  
  検出されたリスク:
  1. 退去届遅延 → 違約金発生（impact: high）
  2. 引越し繁忙期で業者確保困難（impact: medium）
  
  → RISK.jsonに保存しようとする
  → validate-state.sh: 「高リスク'退去届遅延'にmitigation未記入です」
  → ブロック！対応策を入れないと保存できない
  
あなた: 「明日提出する」

  → mitigation: "5/18に提出" で保存成功
```

### Day 14: 進捗更新

```
あなた: 「退去届出した。不動産屋も決めた」

PM-Harness (wbs-update):
  - 退去届提出 → done ✓
  - 不動産屋に連絡 → done ✓
  
  FB-Computational:
  ✓ 期限内に完了
  ⚠ [Warn] 次のマイルストーン「引越し業者選定」まで残り30日。
            残タスク3件。余裕あり。
  
  → STATUS.json 更新
  → CHANGELOG.json に「退去届提出完了、不動産屋A社に決定」を記録
```

### Day 21: 週次レポート

```
あなた: 「今週のまとめ作って」

PM-Harness (weekly-report):
  workspace/weekly-report-2026-05-21.md を生成:
  
  # Weekly Report: 5/15〜5/21
  
  ## 進捗サマリー
  完了: 2件 / 進行中: 1件 / 未着手: 3件
  マイルストーン「引越し業者選定」まであと24日
  
  ## 今週の意思決定
  | 日付 | 決定事項 |
  | 5/18 | 退去届提出 |
  | 5/20 | 不動産屋A社に決定（理由: 初期費用が最安） |
  
  ## リスク状況
  | リスク | 影響度 | 対応策 |
  | 退去届遅延 | high | 5/18に提出済み → 解決 |
  | 繁忙期業者確保 | medium | 3社に見積もり依頼中 |
```

### Day 30: 振り返り

```
あなた: 「振り返りして」

PM-Harness (retro):
  # Retrospective: 5月
  
  ## Good
  - 退去届は遅延したが3日で回復できた
  - 不動産屋の比較検討を早めに行えた
  
  ## Problem  
  - 退去届の期限を見落とした（3日超過）
  - 引越し業者の選定基準を決めずに調べ始めた
  
  ## Try
  - 行政手続きは2週間前にリマインダーを設定
  - 選定基準を先に決めてから比較する
  
  ## ハーネス改善提案
  - anti-patterns: 「選定基準を決めずに比較を始めない」
  → IMPROVEMENTS.json に記録
```

### セッション終了時（毎回自動）

```
（セッションを閉じると裏で自動実行）

L1 ルールFB:
  ✓ 期限超過タスクなし
  ✓ 未対応リスクなし
  ⚠ Open Question '引越し業者の選定基準' 5日未回答 → ALERTS.json に記録

L2 LLM FB（24h経過時）:
  「荷物リストが未着手。梱包作業の開始まで40日だが、
   荷物量によって業者の見積もりが変わるため、先に着手すべき」
  → ALERTS.json に記録

→ 次回セッション開始時に自動表示される
```

---

## アーキテクチャ

```
CLAUDE.md（30行）
    │
    ├── rules/（60行以下）     ← PM判断原則 + ルーティング + anti-patterns
    ├── hooks/（自動実行）     ← セッション管理 + バリデーション + 3層FB
    ├── skills/（11スキル）    ← PMワークフロー
    ├── personas/             ← 役割定義（pm-lead, analyst, reviewer）
    └── policies/             ← ポリシー（risk, communication, quality, loop-monitor）
         │
    ┌────┴─────┐
    ▼          ▼
  docs/      state/
  Markdown   JSON
  (人間向け)  (AI向け)
```

### 3層制御

| 層 | やること | 例 |
|---|---|---|
| **①そもそもさせない** | 構造で間違いを不可能に | JSONスキーマ、allowed-tools、append-only |
| **②やった後に検知** | 3層FBで危険信号を検出 | L1ルール(毎回) + L2 LLM(日次) + Cross-Model(任意) |
| **③仕組み自体を改善** | ステアリングループ | IMPROVEMENTS蓄積 → self-improve → context-review |

### スキル一覧

| スキル | やること | 権限 |
|---|---|---|
| project-init | プロジェクト初期設定 | full |
| context-pack | 情報収集・整理 | edit |
| meeting-import | 議事録→決定事項+TODO | edit |
| wbs-update | WBS進捗更新 | edit |
| risk-check | リスク再評価 | edit |
| draft-update | 下書き生成（送信不可） | **readonly** |
| context-sync | ドキュメント整合性確認 | readonly |
| context-review | ステアリング実行 | full |
| cross-review | Cross-Modelレビュー | readonly |
| retro | 振り返り（/schedule対応） | readonly |
| weekly-report | 週次レポート（/schedule対応） | readonly |

---

## プロジェクトタイプ

```bash
# 日常・個人（最小構成）
bash install.sh --target ~/my-project --type personal

# コンサル・BPR・導入支援（フル構成）
bash install.sh --target ~/my-project --type consulting

# システム開発（フル + SPEC + BACKLOG）
bash install.sh --target ~/my-project --type system_dev
```

---

## ライセンス

MIT
