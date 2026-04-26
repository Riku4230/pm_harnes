#!/bin/bash
# Stop hook: 応答完了ごとに発火
# L2 LLMプロジェクトFBの日次起動判定 + L3ハーネス改善の週次起動判定
# 条件を満たした場合のみ、claude CLIをバックグラウンドで起動
set -e

CWD="${CLAUDE_PROJECT_DIR:-.}"

# state/が存在しなければスキップ
[ ! -d "$CWD/state" ] && exit 0
[ ! -f "$CWD/state/STATUS.json" ] && exit 0

# プロジェクト名が空（未セットアップ）ならスキップ
PROJECT_NAME=$(python3 -c "
import json
s = json.load(open('$CWD/state/STATUS.json'))
print(s.get('project_name', ''))
" 2>/dev/null || echo "")
[ -z "$PROJECT_NAME" ] && exit 0

# --- L2: LLMプロジェクトFB（24h経過時のみ） ---
LLM_HOURS=$(python3 -c "
import json, os
from datetime import datetime
f = os.path.join('$CWD', 'state/ALERTS.json')
if os.path.exists(f):
    data = json.load(open(f))
    ts = data.get('llm_checked')
    if ts:
        print(int((datetime.now()-datetime.fromisoformat(ts)).total_seconds()/3600))
    else:
        print(999)
else:
    print(999)
" 2>/dev/null || echo "999")

if [ "$LLM_HOURS" -ge 24 ]; then
  # claude CLIでL2分析をバックグラウンド実行
  claude -p "あなたはプロジェクトアドバイザー。以下のファイルを読んで危険信号を検出してください。

読むファイル:
1. state/STATUS.json
2. state/RISK.json
3. state/WBS.json
4. state/CHANGELOG.json（直近10件）

観点:
- 意思決定間の矛盾
- スケジュールの現実性
- コミュニケーション上の懸念
- やるべきだがやっていないこと

結果をstate/ALERTS.jsonのllm_alertsフィールドに書き出してください。
llm_checkedフィールドも現在時刻で更新。既存のrule_alertsは変更しない。
高確信のものだけ。" \
    --allowedTools "Read,Write" \
    --model sonnet \
    --max-turns 5 \
    > /dev/null 2>&1 &
fi

# --- L3: ハーネス自己改善（10件+3日 or 20件強制） ---
ITEMS=$(python3 -c "
import json, os
f = os.path.join('$CWD', 'state/IMPROVEMENTS.json')
print(len(json.load(open(f)).get('items',[]))) if os.path.exists(f) else print(0)
" 2>/dev/null || echo "0")

LAST_DAYS=$(python3 -c "
import json, os
from datetime import datetime
f = os.path.join('$CWD', 'state/REVIEW_PROPOSALS.json')
if os.path.exists(f):
    data = json.load(open(f))
    ts = data.get('last_run')
    if ts:
        print((datetime.now()-datetime.fromisoformat(ts)).days)
    else:
        print(999)
else:
    print(999)
" 2>/dev/null || echo "999")

if [ "$ITEMS" -ge 20 ] || ([ "$ITEMS" -ge 10 ] && [ "$LAST_DAYS" -ge 3 ]); then
  claude -p "あなたはハーネスエンジニア。PM-Harnessの改善提案を行ってください。

読むファイル:
1. state/IMPROVEMENTS.json
2. state/SESSION_LOG.json
3. .claude/rules/ 配下の全ファイル

分析:
- IMPROVEMENTS.jsonの頻出パターンを特定
- 改善案を3層に分類:
  ①構造で防げたはず → スキーマ/hookの強化
  ②検知できたはず → L1センサーにチェック追加
  ③新規対応 → 新しいルールやスキル

結果をstate/REVIEW_PROPOSALS.jsonに書き出し:
{\"proposals\": [...], \"last_run\": \"現在時刻ISO8601\"}
rules/やskills/を直接書き換えてはいけない。" \
    --allowedTools "Read,Write" \
    --model sonnet \
    --max-turns 8 \
    > /dev/null 2>&1 &
fi

exit 0
