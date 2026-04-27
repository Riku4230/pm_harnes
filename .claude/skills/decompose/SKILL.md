---
name: decompose
description: Break down WBS tasks into subtasks with dependencies.
when_to_use: 「タスク分解して」「詳細化して」「decompose」「サブタスク作って」
permission_mode: edit
---

# decompose

WBSの粗いタスクをサブタスクに分解する。1-2日で完了できる粒度まで詳細化。

## Required Context
- state/WBS.json
- state/STATUS.json

## ワークフロー

### Step 1: 分解対象の選択

WBS.jsonを読み、未分解のタスク（subtasksが空 or 未定義）を一覧表示。
AskUserQuestionで分解対象を選択。「全部」も可。

### Step 2: サブタスク生成

**粒度基準:**
- 1サブタスク = 1-2日で完了
- 明確な完了条件がある
- これ以上分解しても意味がないレベル

**依存関係:**
- サブタスク間の`depends_on`を定義（IDで参照）
- 並行可能なものは依存なし
- 親タスク間の依存も確認

**サブタスクのフォーマット:**
```json
{"id": "T001-1", "name": "希望条件リスト作成", "status": "not_started", "due": "2026-05-03", "depends_on": []}
```

### Step 3: ユーザー確認

生成したサブタスクを依存関係付きで提示:
```
T001: 物件探し・内見 (〜05-10)
  T001-1: 希望条件リスト作成 (〜05-03)
  T001-2: 候補選定 (〜05-05) ← T001-1
  T001-3: 内見実施 (〜05-08) ← T001-2
  T001-4: 物件決定 (〜05-10) ← T001-3
```

### Step 4: WBS.json更新 + 依存チェック

書き込み後、全体の依存関係に循環がないか確認。
期日整合性も確認（依存先due < 依存元due）。
