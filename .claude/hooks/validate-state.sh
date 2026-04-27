#!/bin/bash
# PostToolUse(Edit|Write) で発火
# state/*.jsonの変更後にImpact Analysis（advisory警告のみ、ブロックしない）
# スキーマ検証はpre-validate-state.sh（PreToolUse）で実行済み
set -e
CWD="${CLAUDE_PROJECT_DIR:-.}"

[ ! -d "$CWD/state" ] && exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except:
    print('')
" 2>/dev/null || echo "")

case "$FILE_PATH" in
  */state/*.json)
    if [ -f "$FILE_PATH" ]; then
      python3 -c "
import json, sys, os

f = '$FILE_PATH'
fname = os.path.basename(f)
data = json.load(open(f))
warnings = []
state_dir = os.path.dirname(f)

# CHANGELOG append-only カウンタ更新
if fname == 'CHANGELOG.json':
    count_file = f + '.count'
    current = len(data.get('entries', []))
    with open(count_file, 'w') as b:
        b.write(str(current))

# --- Impact Analysis (advisory, non-blocking) ---

if fname == 'WBS.json':
    tasks = data.get('tasks', [])
    task_by_id = {}
    def index_tasks(tasks):
        for t in tasks:
            key = t.get('id') or t.get('name', '')
            if key:
                task_by_id[key] = t
            for st in t.get('subtasks', []):
                sk = st.get('id') or st.get('name', '')
                if sk:
                    task_by_id[sk] = st
    index_tasks(tasks)

    for key, t in task_by_id.items():
        for dep_id in t.get('depends_on', t.get('dependencies', [])):
            dep = task_by_id.get(dep_id)
            if dep and dep.get('due') and t.get('start_date'):
                if dep['due'] > t['start_date']:
                    warnings.append(
                        f\"schedule_conflict: '{dep_id}' の期日({dep['due']})が '{key}' の開始日({t['start_date']})より後\")
                elif dep['due'] == t['start_date']:
                    warnings.append(
                        f\"no_buffer: '{dep_id}' 完了日と '{key}' 開始日が同日({dep['due']})\")

    status_path = os.path.join(state_dir, 'STATUS.json')
    if os.path.exists(status_path):
        try:
            status = json.load(open(status_path))
            ct = status.get('current_task')
            if ct and ct not in task_by_id:
                warnings.append(f\"status_drift: STATUS.current_task '{ct}' がWBSに存在しません\")
        except: pass

elif fname == 'STATUS.json':
    wbs_path = os.path.join(state_dir, 'WBS.json')
    if os.path.exists(wbs_path):
        try:
            wbs = json.load(open(wbs_path))
            task_by_id = {}
            def index_tasks(tasks):
                for t in tasks:
                    key = t.get('id') or t.get('name', '')
                    if key: task_by_id[key] = t
                    for st in t.get('subtasks', []):
                        sk = st.get('id') or st.get('name', '')
                        if sk: task_by_id[sk] = st
            index_tasks(wbs.get('tasks', []))
            ct = data.get('current_task')
            if ct and ct not in task_by_id:
                warnings.append(f\"status_drift: current_task '{ct}' がWBS.jsonに存在しません\")
        except: pass

elif fname == 'RISK.json':
    for r in data.get('risks', []):
        if r.get('impact') == 'high' and r.get('status') == 'open':
            warnings.append(f\"high_risk_open: '{r.get('name')}' — WBSタスクへの影響を確認してください\")

if warnings:
    print('--- Impact Analysis ---')
    for w in warnings:
        print(f'  {w}')
" 2>&1
    fi
    ;;
esac
exit 0
