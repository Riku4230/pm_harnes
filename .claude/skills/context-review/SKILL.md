---
name: context-review
description: Apply harness improvements from IMPROVEMENTS/PROPOSALS. Steering loop.
when_to_use: 「改善レビューして」「ハーネス改善」「context-review」「改善適用して」「ハーネス更新」
permission_mode: full
---

# context-review

IMPROVEMENTS/PROPOSALSからハーネス改善を適用する。retroの分析結果を実行に移すスキル。

## Required Context
- state/IMPROVEMENTS.json
- state/REVIEW_PROPOSALS.json（あれば）
- .claude/rules/ 全ファイル

## ワークフロー

### Step 1: 改善提案の確認
REVIEW_PROPOSALS.json（stop-advisorの出力）があれば各提案を提示。
なければIMPROVEMENTS.jsonを直接分析。

### Step 2: 改善の分類
各問題を3層に分類:
- ①で防げたはず → hook/スキーマ強化
- ②で検出できたはず → L1センサーにチェック追加
- 新規 → スキル新設を提案

### Step 3: 適用（ユーザー承認必須）
各改善案をユーザーに提示。承認されたもののみ適用:
- anti-patterns.mdへの昇格（同じ問題3回以上）
- スキルのRequired Context追加
- L1センサーの閾値調整

### Step 4: 剪定
anti-patterns.mdが10件超の場合:
- 3ヶ月未発火 → 削除候補
- 統合可能 → 統合

### Post
- IMPROVEMENTS.jsonの処理済みエントリを削除
- 変更は別ブランチ+PRで適用

### /schedule対応
routineではretro → context-reviewの順で実行。
```
/schedule "毎週金曜: /retro → /context-review"
```
