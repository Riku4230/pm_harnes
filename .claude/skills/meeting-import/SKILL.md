---
name: meeting-import
description: Transcription to minutes. Extract decisions and TODOs.
when_to_use: 「議事録取り込んで」「この会議まとめて」「ミーティングメモ整理」
persona: personas/analyst.md
policy: policies/communication-policy.md
permission_mode: edit
---

# meeting-import

## Required Context
- docs/STAKEHOLDER.md

## Token Budget
〜2,000トークン（文字起こしファイルは別途）

## ワークフロー

### Step 1: 文字起こし読み込み
meeting/ 配下の指定ファイルをRead。

### Step 2: 議事録生成
- 参加者
- 議題
- 議論の要点
- 決定事項（必須）
- TODO（担当者+期限）

### Step 3: 決定事項・TODO抽出
決定事項をstate/CHANGELOG.jsonに追記。
TODOをstate/STATUS.jsonのnext_actionsに反映。

### FB-Computational
- [Block] 決定事項0件 かつ TODO 0件 → 「本当に何も決まっていませんか？」
- [Warn] TODO担当者がdocs/STAKEHOLDER.mdに不在 → 「担当者を追加しますか？」

### Post
- meeting/ に議事録保存
- state/STATUS.json更新
- state/CHANGELOG.json追記
