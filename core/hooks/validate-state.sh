#!/bin/bash
# PostToolUse(Edit|Write) で発火
# state/*.jsonの変更のみ検査: 構文チェック + スキーマバリデーション
set -e
CWD="${CLAUDE_CWD:-.}"

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
        if t.get('start_date') and t.get('due'):
            if t['start_date'] > t['due']:
                errors.append(f'{prefix}: start_date ({t[\"start_date\"]}) > due ({t[\"due\"]})')

elif fname == 'CHANGELOG.json':
    # append-only確認
    count_file = f + '.count'
    current = len(data.get('entries', []))
    if os.path.exists(count_file):
        prev = int(open(count_file).read().strip())
        if current < prev:
            errors.append(f'CHANGELOG.json: entries decreased ({prev} -> {current}), append-only violation')
    with open(count_file, 'w') as b:
        b.write(str(current))
    # エントリのフィールドチェック
    for i, e in enumerate(data.get('entries', [])):
        if not e.get('date'):
            errors.append(f'CHANGELOG.json entries[{i}]: date is required')
        if not e.get('description'):
            errors.append(f'CHANGELOG.json entries[{i}]: description is required')

if errors:
    for e in errors:
        print(f'SCHEMA ERROR: {e}', file=sys.stderr)
    sys.exit(2)
" 2>&1
      if [ $? -ne 0 ]; then
        exit 2
      fi
    fi
    ;;
esac
exit 0
