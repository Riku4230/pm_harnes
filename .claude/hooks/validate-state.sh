#!/bin/bash
# PostToolUse(Edit|Write) で発火
# state/*.jsonの変更のみ検査: 構文チェック + スキーマバリデーション + 影響分析
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
errors = []

# --- JSON構文は既にパス（json.loadが成功） ---

# --- スキーマバリデーション ---

if fname == 'STATUS.json':
    for field in ['project_name', 'project_type']:
        if not data.get(field):
            errors.append(f'STATUS.json: {field} is required and must not be empty')

elif fname == 'RISK.json':
    valid_impact = {'high', 'medium', 'low'}
    valid_prob = {'high', 'medium', 'low'}
    for i, r in enumerate(data.get('risks', [])):
        prefix = f'RISK.json risks[{i}]'
        if not r.get('name'):
            errors.append(f'{prefix}: name is required')
        if r.get('impact') and r['impact'] not in valid_impact:
            errors.append(f'{prefix}: impact must be high/medium/low, got \"{r[\"impact\"]}\"')
        if r.get('probability') and r['probability'] not in valid_prob:
            errors.append(f'{prefix}: probability must be high/medium/low, got \"{r[\"probability\"]}\"')
        if r.get('impact') == 'high' and not r.get('mitigation', '').strip():
            errors.append(f'{prefix}: high-impact risk \"{r.get(\"name\")}\" requires mitigation')

elif fname == 'WBS.json':
    valid_status = {'not_started', 'in_progress', 'done', 'blocked'}
    task_names = set()
    for i, t in enumerate(data.get('tasks', [])):
        prefix = f'WBS.json tasks[{i}]'
        if not t.get('name'):
            errors.append(f'{prefix}: name is required')
        else:
            task_names.add(t['name'])
        if t.get('status') and t['status'] not in valid_status:
            errors.append(f'{prefix}: status must be not_started/in_progress/done/blocked, got \"{t[\"status\"]}\"')
        if t.get('start_date') and t.get('due'):
            if t['start_date'] > t['due']:
                errors.append(f'{prefix}: start_date ({t[\"start_date\"]}) > due ({t[\"due\"]})')
    # 依存関係の循環検出
    tasks = data.get('tasks', [])
    dep_map = {}
    for t in tasks:
        name = t.get('name', '')
        deps = t.get('dependencies', [])
        if name and deps:
            dep_map[name] = deps
    def has_cycle(node, visited, stack):
        visited.add(node)
        stack.add(node)
        for dep in dep_map.get(node, []):
            if dep in stack:
                return True
            if dep not in visited and has_cycle(dep, visited, stack):
                return True
        stack.discard(node)
        return False
    visited = set()
    for name in dep_map:
        if name not in visited:
            if has_cycle(name, visited, set()):
                errors.append(f'WBS.json: dependency cycle detected involving \"{name}\"')

elif fname == 'CHANGELOG.json':
    count_file = f + '.count'
    current = len(data.get('entries', []))
    if os.path.exists(count_file):
        prev = int(open(count_file).read().strip())
        if current < prev:
            errors.append(f'CHANGELOG.json: entries decreased ({prev} -> {current}), append-only violation')
    with open(count_file, 'w') as b:
        b.write(str(current))
    for i, e in enumerate(data.get('entries', [])):
        if not e.get('date'):
            errors.append(f'CHANGELOG.json entries[{i}]: date is required')
        if not e.get('description'):
            errors.append(f'CHANGELOG.json entries[{i}]: description is required')

if errors:
    for e in errors:
        print(f'SCHEMA ERROR: {e}', file=sys.stderr)
    sys.exit(2)

# --- Impact Analysis (advisory, non-blocking) ---
warnings = []
state_dir = os.path.dirname(f)

if fname == 'WBS.json':
    tasks = data.get('tasks', [])
    task_by_name = {t['name']: t for t in tasks if t.get('name')}

    # 依存先の期日 > 依存元の開始日
    for t in tasks:
        for dep_name in t.get('dependencies', []):
            dep = task_by_name.get(dep_name)
            if dep and dep.get('due') and t.get('start_date'):
                if dep['due'] > t['start_date']:
                    warnings.append(
                        f\"schedule_conflict: '{dep_name}' の期日({dep['due']})が '{t['name']}' の開始日({t['start_date']})より後。開始日の後ろ倒しを検討してください\")
                elif dep['due'] == t['start_date']:
                    warnings.append(
                        f\"no_buffer: '{dep_name}' 完了日と '{t['name']}' 開始日が同日({dep['due']})。遅延余地がありません\")

    # STATUS.jsonとの整合性
    status_path = os.path.join(state_dir, 'STATUS.json')
    if os.path.exists(status_path):
        try:
            status = json.load(open(status_path))
            ct = status.get('current_task')
            if ct and ct not in task_by_name:
                warnings.append(f\"status_drift: STATUS.current_task '{ct}' がWBSに存在しません\")
            for action in status.get('next_actions', []):
                for t in tasks:
                    if action == t.get('name') and t.get('dependencies'):
                        unfinished = [d for d in t['dependencies']
                                      if task_by_name.get(d, {}).get('status') != 'done']
                        if unfinished:
                            warnings.append(
                                f\"dependency_order: STATUS.next_actions '{action}' の依存先 {unfinished} が未完了\")
        except: pass

elif fname == 'STATUS.json':
    wbs_path = os.path.join(state_dir, 'WBS.json')
    if os.path.exists(wbs_path):
        try:
            wbs = json.load(open(wbs_path))
            task_by_name = {t['name']: t for t in wbs.get('tasks', []) if t.get('name')}
            ct = data.get('current_task')
            if ct and ct not in task_by_name:
                warnings.append(f\"status_drift: current_task '{ct}' がWBS.jsonに存在しません\")
            for action in data.get('next_actions', []):
                t = task_by_name.get(action)
                if t and t.get('dependencies'):
                    unfinished = [d for d in t['dependencies']
                                  if task_by_name.get(d, {}).get('status') != 'done']
                    if unfinished:
                        warnings.append(
                            f\"dependency_order: next_actions '{action}' の依存先 {unfinished} が未完了\")
        except: pass

elif fname == 'RISK.json':
    wbs_path = os.path.join(state_dir, 'WBS.json')
    if os.path.exists(wbs_path):
        try:
            wbs = json.load(open(wbs_path))
            for r in data.get('risks', []):
                if r.get('impact') == 'high' and r.get('status') == 'open':
                    warnings.append(
                        f\"high_risk_open: '{r.get('name')}' — WBSタスクへの影響を確認してください\")
        except: pass

if warnings:
    print('--- Impact Analysis ---')
    for w in warnings:
        print(f'  {w}')
" 2>&1
      RESULT=$?
      if [ $RESULT -eq 2 ]; then
        exit 2
      fi
    fi
    ;;
esac
exit 0
