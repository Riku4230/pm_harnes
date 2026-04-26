---
name: context-review
description: ステアリングループ実行。IMPROVEMENTS/REVIEW_PROPOSALSを基にハーネスを改善。
when_to_use: 「改善レビューして」「ハーネス改善」「context-review」
persona: personas/pm-lead.md
policy: policies/quality-policy.md
permission_mode: full
---

# context-review

## Required Context
- state/IMPROVEMENTS.json
- state/REVIEW_PROPOSALS.json（あれば）
- state/SESSION_LOG.json
- .claude/rules/ 全ファイル

## ワークフロー

### Step 1: 改善提案の確認
REVIEW_PROPOSALS.json（self-improve.tsの出力）があれば、各提案を提示。
なければIMPROVEMENTS.jsonを直接分析。

### Step 2: パターン分析
- IMPROVEMENTS.jsonの頻出パターンを特定
- SESSION_LOG.jsonで繰り返しの傾向を確認

### Step 3: 改善の分類
各問題を3層制御に分類:
- ①で防げたはず → Computational Guideを強化（スキーマ/hook/allowed-tools）
- ②で検出できたはず → L1センサーにチェック追加
- 新しいトポロジーが必要 → スキル新設を提案

### Step 4: 適用（ユーザー承認必須）
各改善案をユーザーに提示。承認されたもののみ適用:
- anti-patterns.mdへの昇格
- スキルのRequired Context追加
- L1センサーの閾値調整

### Step 5: 剪定
anti-patterns.mdが10件超の場合:
- 3ヶ月未発火のルール → 削除候補
- 統合可能なルール → 統合

### Step 6: Verify
適用した改善について、次回以降の該当トポロジー実行時に
同種インシデントの再発をL1で自動監視。2週間再発なしで「verified」。

### Post
- IMPROVEMENTS.jsonの処理済みエントリを削除
- rules/skills/の変更をコミット
