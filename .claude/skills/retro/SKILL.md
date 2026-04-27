---
name: retro
description: Retrospective analysis. Review decisions, patterns, lessons learned.
when_to_use: 「振り返りして」「レトロスペクティブ」「今週の反省」「何がうまくいった？」「反省会」
allowed-tools: Read, Write
permission_mode: edit
---

# retro

振り返り分析 → 教訓生成 → レポート出力。改善の適用はcontext-reviewに委譲。

## Required Context
- state/CHANGELOG.json
- state/IMPROVEMENTS.json
- state/SESSION_LOG.json
- state/STATUS.json
- state/RISK.json
- state/ALERTS.json

## Token Budget
〜5,000トークン

## ワークフロー

### Phase 1: 振り返り分析

対象期間を確認（デフォルト: 直近1週間）。

**意思決定の振り返り**（CHANGELOG.json）:
- どんな決定をしたか
- その決定は現在も妥当か

**問題パターンの分析**（IMPROVEMENTS.json）:
- 頻出する問題カテゴリ
- 同じ問題が3回以上繰り返されていないか → anti-patterns昇格候補
- どの層（①構造 ②検知 ③改善）で防げたか

**セッション活動**（SESSION_LOG.json）:
- よく使われたスキル
- よく編集されたファイル

### Phase 2: 教訓レポート生成

workspace/retro-{date}.mdに生成:

```markdown
# Retrospective: {期間}

## Good（うまくいったこと）
## Problem（問題だったこと）
## Try（次に試すこと）

## ハーネス改善候補
| # | 対象 | 変更案 | 層 | 根拠 |
```

### Phase 3: 改善候補の記録

改善候補をstate/IMPROVEMENTS.jsonに追記。
**実際の適用は `/context-review` で行う。retroは分析と記録まで。**

### /schedule対応
```
/schedule で定期実行可能。
自動実行時: Phase 1-2（分析+レポート）→ mainにcommit+push。
```
