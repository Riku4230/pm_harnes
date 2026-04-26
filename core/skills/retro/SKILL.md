---
name: retro
description: Retrospective + harness improvement. Analyze, learn, apply fixes.
when_to_use: 「振り返りして」「レトロスペクティブ」「改善して」「今週の反省」
allowed-tools: Read, Write, Edit
persona: personas/pm-lead.md
policy: policies/quality-policy.md
permission_mode: full
---

# retro

振り返り → 教訓生成 → **ハーネス改善の適用**まで一括で行う。
③ステアリングループの実行スキル。

## Required Context
- state/CHANGELOG.json
- state/IMPROVEMENTS.json
- state/SESSION_LOG.json
- state/STATUS.json
- state/RISK.json
- state/ALERTS.json
- .claude/rules/03-anti-patterns.md

## Token Budget
〜5,000トークン

## ワークフロー

### Phase 1: 振り返り分析

対象期間を確認（デフォルト: 直近1週間）。

**意思決定の振り返り**（CHANGELOG.json）:
- どんな決定をしたか
- その決定は現在も妥当か
- 撤回・修正された決定はないか

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

## ハーネス改善案
| # | 対象 | 変更 | 層 | 根拠（インシデント） |
```

### Phase 3: ハーネス改善の適用

改善案を1つずつユーザーに提示。承認されたもののみ適用。

**同じミスが3回 → anti-patternsに昇格:**
- IMPROVEMENTS.jsonで同種の問題が3回以上 → rules/03-anti-patterns.mdに追加
- エントリには必ず「日付・インシデント・対策」を記載
- 例: `## AP-001: WBS更新前にリスク確認漏れ (2026-05-01) - WBS更新時にRISK.jsonも確認する`

**不要ルールは3ヶ月未発火で剪定:**
- anti-patterns.mdの各ルール作成日を確認
- 直近のALERTS.jsonに関連する検出がないルール → 削除候補
- 10件超の場合は必ず剪定

**context-routingの更新:**
- 「このファイルをRequired Contextに追加すべきだった」→ routing表に追加
- 「このスキルでこのファイルを読むべきだった」→ スキルのRequired Context追記

**policiesの更新:**
- 新しいルールや基準 → 該当policyファイルに追記

### Phase 4: クリーンアップ

- IMPROVEMENTS.jsonの処理済みエントリを削除
- REVIEW_PROPOSALS.jsonがあれば適用済み提案を削除
- state/STATUS.json更新

### /schedule対応
```
/schedule で定期実行可能。
schedule実行時: Phase 1-2（分析+レポート）のみ。Phase 3はスキップ。
手動実行時: Phase 1-4（分析+レポート+改善適用+クリーンアップ）全実行。
```
