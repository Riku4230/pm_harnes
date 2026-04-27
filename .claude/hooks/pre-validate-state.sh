#!/bin/bash
# PreToolUse(Edit|Write|apply_patch) で発火
# state/*.json への書き込みを事前にシミュレートしてスキーマ検証
# PreToolUseなのでexit 2で書き込みを実際にブロックできる
set -e
CWD="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$CWD/state" ] && exit 0

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import json, sys, os, re

inp = json.load(sys.stdin)
tool_name = inp.get('tool_name', '')
tool_input = inp.get('tool_input', {})

# ファイルパスとシミュレート内容を取得
file_path = ''
content_str = ''

if tool_name in ('Write',):
    file_path = tool_input.get('file_path', '')
    content_str = tool_input.get('content', '')

elif tool_name in ('Edit',):
    file_path = tool_input.get('file_path', '')
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

elif tool_name == 'apply_patch':
    patch = tool_input.get('patch', '')
    # パッチからファイルパスを取得
    for line in patch.split(chr(10)):
        if line.startswith('*** Update File:') or line.startswith('*** Add File:'):
            file_path = line.split(':', 1)[1].strip()
            break
    if not file_path:
        sys.exit(0)
    # Add File: 新規作成 → パッチの+行を結合
    if '*** Add File:' in patch:
        lines = []
        in_content = False
        for line in patch.split(chr(10)):
            if line.startswith('*** Add File:'):
                in_content = True
                continue
            if line.startswith('*** '):
                break
            if in_content and line.startswith('+'):
                lines.append(line[1:])
        content_str = chr(10).join(lines)
    # Update File: 既存ファイルにパッチ適用（簡易: 変更後のファイルを読む方式は使えないのでベストエフォート）
    elif os.path.exists(file_path):
        # パッチ適用のシミュレートは複雑なので、簡易チェック:
        # -行を削除、+行を追加した結果をシミュレート
        current = open(file_path).read()
        current_lines = current.split(chr(10))
        result_lines = []
        patch_lines = patch.split(chr(10))
        i = 0
        in_hunk = False
        removed = set()
        added = []
        for pl in patch_lines:
            if pl.startswith('@@'):
                in_hunk = True
                continue
            if pl.startswith('*** '):
                in_hunk = False
                continue
            if in_hunk:
                if pl.startswith('-'):
                    removed.add(pl[1:])
                elif pl.startswith('+'):
                    added.append(pl[1:])
        # 簡易適用: removed行を削除してadded行を末尾追加ではなく、
        # 元ファイルから-行を除去して+行を挿入位置に追加
        # 正確なパッチ適用は困難なので、変更後にJSON parseできるかだけチェック
        try:
            # とりあえず元ファイルからremoved行を消してadded行を追加
            for rl in removed:
                stripped = rl.strip()
                current = current.replace(rl, '', 1)
            # この段階でJSONとしてパースを試みる
            for al in added:
                current = current.rstrip() + chr(10) + al
            content_str = current
        except:
            sys.exit(0)
    else:
        sys.exit(0)
else:
    sys.exit(0)

if not file_path or '/state/' not in file_path or not file_path.endswith('.json'):
    sys.exit(0)

fname = os.path.basename(file_path)

skip_files = {'SESSION_LOG.json', 'ALERTS.json', 'SOURCES.json',
              'IMPROVEMENTS.json', 'BACKLOG.json', 'REVIEW_PROPOSALS.json'}
if fname in skip_files:
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

    for p, t in all_tasks:
        if not t.get('name'):
            errors.append(f'{p}: name is required')
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
