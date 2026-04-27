---
name: doc-check
description: Check docs/state/ consistency and freshness.
when_to_use: 「ドキュメント確認して」「整合性チェック」「情報の鮮度確認」「ドキュメント同期して」「doc-check」
permission_mode: readonly
---

# doc-check

docs/とstate/のメタデータを比較し、鮮度と矛盾を検出する。

## Required Context
- docs/ 全ファイルのメタデータ（ファイル名+更新日のみ）
- state/STATUS.json

## Token Budget
〜2,000トークン

## ワークフロー

### Step 1: メタデータ収集
docs/とstate/の各ファイルの更新日を確認。

### Step 2: 鮮度チェック
30日以上更新されていないファイルを特定。

### Step 3: 矛盾検出（段階的読み込み）
古いファイルや疑わしいファイルのみ全文Readして:
- docs/間の矛盾
- docs/ ↔ state/の不一致

### Post
- 修正提案をユーザーに提示（自動修正はしない）
