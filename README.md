# PM-Harness

**Claude Codeで動くAI-PMO。プロジェクトの危険信号を自動検知し、PMの判断を支える。**

PM-Harnessは、PMの代わりに判断するのではなく、**進捗遅れ・リスク放置・意思決定の矛盾・共有漏れを自動検知し、PMの注意を重要箇所に向ける**制御システム。

人間のPMOが定例会議でやっていることを、Claude Codeのhooks + skillsで自動化した。

ハーネスエンジニアリング（Böckeler / Osmani / Hashimoto等）の設計思想をPM業務に翻訳した、おそらく初の体系的実装。

---

## 何ができるか

### セッションを開くだけで状況が分かる

```
## Current Status
Project: X案件 / Phase: 設計 / Updated: 2026-04-25

## Alerts
🔴 [rule] タスク'要件定義書レビュー'が5日超過
🔴 [rule] 高リスク'ベンダー選定遅延'の対応策が未定義
🟡 [llm] 4/20の『スコープ縮小』と4/23の『機能A追加』が矛盾
🟡 [rule] Open Question 'API仕様' が7日間未回答
```

hooks（session-start.sh）がセッション開始時にstate/を読み、**何もしなくても危険信号が表示される**。

### 間違いが構造的に起きない

- 高リスクに対応策なしで保存 → **JSONスキーマでブロック**
- AIの外部直接送信 → **スキル指示で禁止（構造的ブロックではなく運用ルール）**
- 過去の意思決定を改ざん → **append-only制約でブロック**

「気をつけてね」ではなく、**間違いが物理的に起きない環境**を作る。

### ハーネスが自分で育つ

ミスが発生 → IMPROVEMENTS.jsonに蓄積 → retroで週次分析 → 改善提案 → PMが承認 → ハーネスが改善される。

---

## クイックスタート

### 1. コピー

```bash
git clone https://github.com/Riku4230/pm_harnes.git ~/my-project
cd ~/my-project
```

### 2. セットアップ

```bash
claude
```

Claude Codeが起動したら:

```
あなた: 「セットアップして」
```

`/setup` がヒアリングから全部やる:

```
PM-Harness: プロジェクト名は？
あなた: 「新商品のブランディングプロジェクト」

PM-Harness: ゴールは？
あなた: 「6月末までに新商品のブランド戦略を策定して、社内承認を得る」

PM-Harness: 関係者は？
あなた: 「マーケ部の田中さん、デザイン会社のA社、経営企画の佐藤さん」

→ 必要なファイルを判定して生成
→ Git初期化
→ GitHub連携（希望時）
→ Schedule設定（source-sync毎日、weekly-report毎週金曜、retro毎週金曜）
→ 完了！
```

### 3. 作業開始

以降は普通に話しかけるだけ:

```
「やること洗い出して」        → WBS作成
「議事録まとめて」           → 決定事項+TODO抽出
「リスクチェックして」        → リスク台帳更新
「報告の下書き作って」        → ステークホルダー向け下書き
「振り返りして」             → レトロスペクティブ
「今週のまとめ」             → 週次レポート
```

---

## 具体例: ブランディングプロジェクト

### Week 1: キックオフ後

```
あなた: 「今日のキックオフの議事録まとめて」

PM-Harness (meeting-import):
  ✓ 決定事項3件抽出
  ✓ TODO5件抽出（担当者付き）
  ⚠ [Warn] TODO担当者「鈴木さん」がSTAKEHOLDER.mdにいません → 追加しますか？

あなた: 「追加して。あとWBSも作って」

PM-Harness (wbs-update):
  ✓ タスク15件生成（キックオフの決定事項ベース）
  ✓ マイルストーン: 中間報告 5/15、最終報告 6/30
  ✓ 依存関係チェック OK
```

### Week 2: セッション開始時

```
（自動表示）
## Alerts
🟡 [rule] タスク'ブランドコンセプト案作成'の期限が明日
🟡 [rule] Open Question 'ロゴの方向性' が5日間未回答（owner: A社）
🟡 [llm] 中間報告まで20日。消化率25%。このペースだと5日超過の見込み
```

### Week 3: リスク対応

```
あなた: 「リスクチェックして」

PM-Harness (risk-check):
  新規リスク検出:
  1. デザイン会社A社の納品遅延（impact: high）
  
  → RISK.jsonに保存しようとする
  → ❌ ブロック！「高リスクにmitigation未記入です」
  
あなた: 「代替のB社に連絡済み。最悪切り替える」

  → mitigation: "代替B社に連絡済み。2週間反応なければ切り替え" で保存 ✓
```

### Week 4: 週次レポート

```
あなた: 「今週のまとめ作って」

PM-Harness (weekly-report):
  workspace/weekly-report-2026-05-25.md を生成:
  
  # Weekly Report: 5/19〜5/25
  ## 進捗: 完了4件 / 進行中6件 / ブロック1件
  ## 決定事項: ブランドコンセプト「XXX」に決定
  ## リスク: A社納品遅延（対応策あり）
  ## 来週: 中間報告資料作成、佐藤さんとの事前すり合わせ
  
  （PMが確認後、Slackで共有）
```

### 月末: 振り返り

```
あなた: 「振り返りして」

PM-Harness (retro):
  ## Good
  - リスクの早期検出でA社→B社への切り替えがスムーズだった
  
  ## Problem
  - Open Questionの放置が多い（平均5日）
  - 中間報告が3日遅延
  
  ## ハーネス改善提案
  - Open Questionは3日でリマインダー → anti-patternsに追加
```

---

## アーキテクチャ

### 3層制御

PM-Harnessの設計の中心軸。

| 層 | やること | 例 |
|---|---|---|
| **①そもそもさせない** | 構造で間違いを不可能に | JSONスキーマ、allowed-tools、append-only |
| **②やった後に検知** | 3層FBで危険信号を検出 | L1ルール(毎回) + L2 LLM(6h間隔) + Cross-Model(任意) |
| **③仕組み自体を改善** | ステアリングループ | IMPROVEMENTS蓄積 → retro → ハーネス改善適用 |

### フォルダ構成

```
my-project/
├── CLAUDE.md                 ← プロジェクト概要（30行）
├── .claude/
│   ├── rules/                ← PM判断原則（60行以下）
│   ├── hooks/                ← 自動実行（セッション管理 + 3層FB）
│   ├── skills/               ← PMワークフロー（12スキル）
│   └── settings.json         ← hooks登録
├── docs/                     ← 人間向けドキュメント（Markdown）
│   ├── PROJECT.md
│   ├── STAKEHOLDER.md
│   └── COMMUNICATION.md
├── state/                    ← AI向け構造化データ（JSON）
│   ├── STATUS.json
│   ├── RISK.json
│   ├── WBS.json
│   ├── CHANGELOG.json
│   └── ...
├── meeting/                  ← 議事録（YYYY-MM-DD_会議名.md）
└── workspace/                ← 作業成果物（下書き、レポート）
```

### スキル一覧

| スキル | やること | 権限 |
|---|---|---|
| setup | 初回セットアップ（ヒアリング→ファイル生成→Git→Schedule） | full |
| source-sync | Slack/Notion等から情報取得（定期実行可） | edit |
| meeting-import | 議事録→決定事項+TODO | edit |
| wbs-update | WBS進捗更新 | edit |
| decompose | タスク分解（1-2日粒度） | edit |
| risk-check | リスク再評価 | edit |
| draft-update | 下書き生成（送信不可） | edit |
| doc-check | ドキュメント整合性確認 | readonly |
| context-review | ステアリング実行 | full |
| cross-review | Cross-Modelレビュー | readonly |
| retro | 振り返り+ハーネス改善（定期実行可） | full |
| weekly-report | 週次レポート（定期実行可） | edit |

### ファイル生成

`/setup` がプロジェクト内容をヒアリングし、必要なファイルだけを動的に生成する。タイプを事前に選ぶ必要はない。

| 状況 | 生成されるファイル |
|---|---|
| 全プロジェクト共通 | STATUS.json, CHANGELOG.json, PROJECT.md 等（7ファイル） |
| 関係者がいる | + STAKEHOLDER.md, COMMUNICATION.md |
| スケジュール管理が必要 | + WBS.json, RISK.json |
| システム開発 | + SPEC.md, BACKLOG.json |

---

## 設計思想

詳細は [DESIGN.md](DESIGN.md) を参照。

---

## License

MIT
