---
name: context-sync
description: Check docs/state/ consistency and freshness.
when_to_use: 「ドキュメント同期して」「整合性チェック」「情報の鮮度確認」
permission_mode: readonly
---

# context-sync

## Required Context
- docs/ 全ファイルのメタデータ（ファイル名+更新日のみ。全文は読まない）
- state/STATUS.json

## Token Budget
〜2,000トークン（メタデータのみ。詳細は段階的に読む）

## ワークフロー

### Step 1: メタデータ収集
docs/とstate/の各ファイルの更新日を確認。

### Step 2: 鮮度チェック
30日以上更新されていないファイルを特定。

### Step 3: 矛盾検出（段階的読み込み）
古いファイルや疑わしいファイルのみ全文Readして:
- docs/間の矛盾
- docs/ ↔ state/の不一致

### FB-Computational
- [Warn] 最終更新30日超のファイル
- [Log] IMPROVEMENTS.json 10件超 → 「context-reviewを実行してください」

### Post
- 修正提案をユーザーに提示（自動修正はしない）
