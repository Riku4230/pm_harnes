---
name: retro
description: Retrospective. Analyze logs, generate lessons. Schedulable.
when_to_use: 「振り返りして」「レトロスペクティブ」「今週の反省」「スプリント振り返り」
allowed-tools: Read, Write
permission_mode: edit---

# retro

## Required Context
- state/CHANGELOG.json
- state/IMPROVEMENTS.json
- state/SESSION_LOG.json
- state/STATUS.json
- state/RISK.json

## Token Budget
〜5,000トークン

## Permission Mode
**readonly** — 分析と提案のみ。ファイル変更はcontext-reviewで行う。

## ワークフロー

### Step 1: 期間の確認
対象期間を確認（デフォルト: 直近1週間）。
SESSION_LOG.jsonから対象期間のセッション数を把握。

### Step 2: 意思決定の振り返り
CHANGELOG.jsonから対象期間のエントリを抽出:
- どんな決定をしたか
- その決定は現在も妥当か
- 撤回・修正された決定はないか（Decision Drift）

### Step 3: 問題パターンの分析
IMPROVEMENTS.jsonから:
- 頻出する問題カテゴリの特定
- 同じ問題が繰り返されていないか
- どの層（①構造 ②検知 ③改善）で防げたか

### Step 4: リスクの振り返り
RISK.jsonから:
- 対応策が機能したリスク
- 想定外だったリスク
- 見落としていたリスク

### Step 5: 教訓の生成
以下の形式でworkspace/に振り返りレポートを生成:

```markdown
# Retrospective: {期間}

## Good（うまくいったこと）
## Problem（問題だったこと）
## Try（次に試すこと）

## ハーネス改善提案
- ①に昇格すべき: ...
- ②に追加すべき: ...
- anti-patternsに追加すべき: ...
```

### Step 6: 改善提案の記録
Tryの中でハーネス改善に関するものをstate/IMPROVEMENTS.jsonに追記。
context-reviewで承認後に適用。

### /schedule対応
```
/schedule で「毎週金曜 17:00にretroを実行」が可能。
実行結果はworkspace/retro-{date}.mdに保存され、
次回セッション開始時に通知される。
```
