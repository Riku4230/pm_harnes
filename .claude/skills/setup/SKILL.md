---
name: setup
description: Full project setup. Hearing, file generation, git, schedules.
when_to_use: 「セットアップして」「setup」「プロジェクト始めたい」「初期設定」
---

# setup

PM-Harnessの初回セットアップ。プロジェクト内容をヒアリングし、必要なファイルを動的に生成する。

## 前提

pm-harnesリポジトリをフォルダにコピー済みで、.claude/が存在すること。

## ワークフロー

### Step 1: プロジェクトヒアリング

以下を対話で確認する:

1. **何のプロジェクトか** — 1文で説明してもらう
2. **ゴール** — 何を達成したら成功か
3. **期限** — いつまでか（あれば）
4. **関係者** — 誰が関わるか。クライアントはいるか
5. **進め方のイメージ** — フェーズがあるか、繰り返し型か

### Step 2: 必要ファイルの判定

ヒアリング内容からどのファイルが必要か判定し、ユーザーに提示して確認する。

#### 全プロジェクト共通（必ず生成）

| ファイル | 用途 |
|---|---|
| state/STATUS.json | プロジェクト状態管理 |
| state/CHANGELOG.json | 意思決定ログ |
| state/IMPROVEMENTS.json | 改善提案蓄積 |
| state/SESSION_LOG.json | セッション履歴 |
| state/ALERTS.json | アラート管理 |
| state/REVIEW_PROPOSALS.json | ハーネス改善提案 |
| docs/PROJECT.md | プロジェクト概要 |

#### 関係者がいる場合

| ファイル | 用途 | 判定基準 |
|---|---|---|
| docs/STAKEHOLDER.md | 関係者一覧と役割 | クライアントやチームメンバーがいる |
| docs/COMMUNICATION.md | コミュニケーションルール | 外部ステークホルダーがいる |

#### スケジュール管理が必要な場合

| ファイル | 用途 | 判定基準 |
|---|---|---|
| state/WBS.json | タスク・スケジュール管理 | 期限がある、複数タスクがある |
| state/RISK.json | リスク台帳 | 期限がある、関係者がいる、不確実性がある |

#### システム開発の場合

| ファイル | 用途 | 判定基準 |
|---|---|---|
| docs/SPEC.md | 技術仕様 | コーディング・システム構築がある |
| state/BACKLOG.json | 開発バックログ | イシュー管理が必要 |

#### ヒアリング例と生成ファイル

**「3ヶ月後に引越しする」（個人タスク）**
→ 共通 + WBS.json（タスク管理） = 8ファイル
→ STAKEHOLDER不要、RISK不要（小規模なので）

**「クライアントの業務プロセスを改善する」（コンサル）**
→ 共通 + STAKEHOLDER + COMMUNICATION + WBS + RISK = 11ファイル

**「社内向けダッシュボードを開発する」（システム開発）**
→ 共通 + STAKEHOLDER + COMMUNICATION + WBS + RISK + SPEC + BACKLOG = 13ファイル

**「新しい趣味としてランニングを始める」（個人目標）**
→ 共通のみ = 7ファイル

ユーザーに「これらのファイルを生成します。過不足ありますか？」と確認。

### Step 3: ファイル生成

確認済みのファイルを生成。同時にディレクトリも作成:
- docs/
- state/
- meeting/ — 議事録格納（YYYY-MM-DD_会議名.md）
- workspace/ — 作業成果物（下書き、レポート）

### Step 4: 初期コンテキスト投入

ヒアリング内容を各ファイルに記入:
- state/STATUS.json: project_name, current_phase, next_actions, open_questions
- docs/PROJECT.md: ゴール、スコープ、期限、制約
- docs/STAKEHOLDER.md: 関係者情報（該当する場合）
- state/WBS.json: 初期タスク生成（期限から逆算。最初のアクション3-5個）
- state/RISK.json: 初期リスク（ヒアリングで出た懸念点）

CLAUDE.mdにproject_nameを記入。

### Step 5: Git初期化 + GitHub連携

```bash
git init  # 既にgitリポジトリでなければ
```

.gitignore生成（なければ）:
```
state/*.count
node_modules/
```

GitHub連携を提案:
- 「GitHubリポジトリを作成しますか？週次レポートの自動実行に必要です。」
- 作成する → `gh repo create {project_name} --private --source=. --push`
- スキップ → schedule は後で設定可能と案内

初回コミット:
```bash
git add -A
git commit -m "PM-Harness: project setup"
git push  # GitHub連携済みの場合
```

### Step 6: Schedule設定

**前提: GitHubリモートが設定済みであること。**

以下を提案（承認されたもののみ設定）:

| スケジュール | 内容 | 推奨 |
|---|---|---|
| **source-sync** | Slack/Notion等から情報取得 | 毎日 9:00 |
| **weekly-report** | 週次レポート生成 | 毎週金曜 16:00 |
| **retro** | 振り返り+ハーネス改善 | 毎週金曜 17:00 |

Claude Codeの `/schedule` で設定。

### Step 7: 情報ソース設定

「Slack/Notionなど、プロジェクトの情報がある場所はありますか？」

ユーザーが情報ソースを持っている場合:
- Slack: チャンネル名とチャンネルIDを聞いてSOURCES.jsonに追加
- Notion: ページ名とページIDを聞いてSOURCES.jsonに追加
- その他: 名前とアクセス方法を聞いて追加

情報ソースがない場合: スキップ。後からsource-syncスキルで追加可能。

sources/ ディレクトリを作成（slack/, notion/, other/）。

### Step 8: 完了

```
PM-Harnessセットアップ完了！

✅ プロジェクト: {project_name}
✅ ファイル: {生成したファイル一覧}
✅ Git/GitHub: {状況}
✅ 情報ソース: {登録したソース or "なし（後から追加可能）"}
✅ Schedule: {設定内容}
✅ Hooks: 自動有効
   - セッション開始: 状況+アラート自動表示
   - 応答完了: L2プロジェクトFB（6h間隔）
   - セッション終了: L1ルールFB自動実行
   - ファイル編集: JSONバリデーション自動実行

最初のタスク:
  {WBS.jsonの最初のnext_actionsから3件表示}

何から始めますか？
```
