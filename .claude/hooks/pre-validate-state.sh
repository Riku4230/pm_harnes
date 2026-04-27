#!/bin/bash
# PreToolUse(Edit|Write) で発火
# state/*.json への書き込みを事前にシミュレートしてスキーマ検証
# PreToolUseなのでexit 2で書き込みを実際にブロックできる
set -e
CWD="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$CWD/state" ] && exit 0

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import json, sys, os

inp = json.load(sys.stdin)
tool_name = inp.get('tool_name', '')
tool_input = inp.get('tool_input', {})
file_path = tool_input.get('file_path', '')

if not file_path or '/state/' not in file_path or not file_path.endswith('.json'):
    sys.exit(0)

fname = os.path.basename(file_path)

# スキーマ検証対象外
skip_files = {'SESSION_LOG.json', 'ALERTS.json', 'SOURCES.json',
              'IMPROVEMENTS.json', 'BACKLOG.json', 'REVIEW_PROPOSALS.json'}
if fname in skip_files:
    sys.exit(0)

# 書き込み後の内容をシミュレート
if tool_name == 'Write':
    content_str = tool_input.get('content', '')
elif tool_name == 'Edit':
    old_string = tool_input.get('old_string', '')
    new_string = tool_input.get('new_string', '')
    replace_all = tool_input.get('replace_all', False)
    if not os.path.exists(file_path):
        sys.exit(0)
    current = open(file_path).read()
    if replace_all:
        content_str = current.replace(old_string, new_string)
    else:
        content_str = current.replace(old_string, new_string, 1)
else:
    sys.exit(0)

try:
    data = json.loads(content_str)
except json.JSONDecodeError as e:
    print(f'BLOCKED: {fname} — Invalid JSON: {e}', file=sys.stderr)
    sys.exit(2)

errors = []

if fname == 'STATUS.json':
    for field in ['project_name', 'project_type']:
        if not data.get(field):
            errors.append(f'{field} is required and must not be empty')

elif fname == 'RISK.json':
    valid_levels = {'high', 'medium', 'low'}
    for i, r in enumerate(data.get('risks', [])):
        if not r.get('name'):
            errors.append(f'risks[{i}]: name is required')
        if r.get('impact') and r['impact'] not in valid_levels:
            errors.append(f'risks[{i}]: impact must be high/medium/low')
        if r.get('probability') and r['probability'] not in valid_levels:
            errors.append(f'risks[{i}]: probability must be high/medium/low')
        if r.get('impact') == 'high' and not r.get('mitigation', '').strip():
            errors.append(f'risks[{i}]: high-impact risk requires mitigation')

elif fname == 'WBS.json':
    valid_status = {'not_started', 'in_progress', 'done', 'blocked'}
    all_tasks = []
    def collect_tasks(tasks, prefix=''):
        for i, t in enumerate(tasks):
            p = f'{prefix}tasks[{i}]'
            all_tasks.append((p, t))
            for j, st in enumerate(t.get('subtasks', [])):
                all_tasks.append((f'{p}.subtasks[{j}]', st))
    collect_tasks(data.get('tasks', []))

    task_ids = set()
    for p, t in all_tasks:
        if not t.get('name'):
            errors.append(f'{p}: name is required')
        if t.get('id'):
            task_ids.add(t['id'])
        if t.get('status') and t['status'] not in valid_status:
            errors.append(f'{p}: status must be not_started/in_progress/done/blocked')
        if t.get('start_date') and t.get('due'):
            if t['start_date'] > t['due']:
                errors.append(f'{p}: start_date > due')

    dep_map = {}
    for _, t in all_tasks:
        tid = t.get('id') or t.get('name', '')
        deps = t.get('depends_on', t.get('dependencies', []))
        if tid and deps:
            dep_map[tid] = deps
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
    for tid in dep_map:
        if tid not in visited:
            if has_cycle(tid, visited, set()):
                errors.append(f'dependency cycle detected involving \"{tid}\"')

elif fname == 'CHANGELOG.json':
    count_file = file_path + '.count'
    current_count = len(data.get('entries', []))
    if os.path.exists(count_file):
        try:
            prev = int(open(count_file).read().strip())
            if current_count < prev:
                errors.append(f'entries decreased ({prev} -> {current_count}), append-only violation')
        except: pass
    for i, e in enumerate(data.get('entries', [])):
        if not e.get('date'):
            errors.append(f'entries[{i}]: date is required')
        if not e.get('description'):
            errors.append(f'entries[{i}]: description is required')

if errors:
    print(f'BLOCKED: {fname} schema validation failed:', file=sys.stderr)
    for e in errors:
        print(f'  - {e}', file=sys.stderr)
    sys.exit(2)
" 2>&1

RESULT=$?
[ $RESULT -eq 2 ] && exit 2
exit 0
