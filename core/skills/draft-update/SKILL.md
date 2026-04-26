---
name: draft-update
description: ステークホルダー向けの下書きを生成する。送信は行わない。
when_to_use: 「報告書の下書き作って」「クライアントへの共有文作って」「進捗報告の下書き」
allowed-tools: Read
persona: personas/pm-lead.md
policy: policies/communication-policy.md
permission_mode: readonly
---

# draft-update

## Required Context
- docs/STAKEHOLDER.md
- docs/COMMUNICATION.md
- state/STATUS.json

## Token Budget
〜3,000トークン

## 構造制約
**Write/Edit/Slack送信は不許可。allowed-tools: Read のみ。**
下書きはworkspace/に保存し、送信判断と実行は必ず人間が行う。

## ワークフロー

### Step 1: 宛先と目的の確認
- 誰に送るか（STAKEHOLDER.mdから特定）
- 何を伝えるか（STATUS.json, RISK.jsonの要約）
- どの粒度か（COMMUNICATION.mdのルール参照）

### Step 2: 下書き生成
宛先の役割・関心に応じた下書きを生成。
workspace/ に保存。

### Step 3: 確認
下書きをユーザーに提示。ユーザーが確認・修正後に自分で送信する。

### FB-Computational
- [Warn] 宛先がSTAKEHOLDER.mdに不在

### Post
- state/CHANGELOG.json追記（下書き生成の記録のみ）
