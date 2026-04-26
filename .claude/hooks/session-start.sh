#!/bin/bash
# SessionStart で発火
# STATUS.json要約 + ALERTS.json表示 + Bootstrap Check
set -e

# CLAUDE_PROJECT_DIRまたはカレントディレクトリ
CWD="${CLAUDE_PROJECT_DIR:-.}"

# --- Bootstrap Check ---
if [ ! -d "$CWD/state" ]; then
  echo "## PM-Harness: state/ directory not found"
  echo "Run setup skill to set up this project."
  exit 0
fi

if [ ! -f "$CWD/state/STATUS.json" ]; then
  echo "## PM-Harness: STATUS.json not found"
  echo "Run setup skill to initialize project state."
  exit 0
fi

# --- STATUS.json要約 ---
python3 -c "
import json, sys
try:
    with open('$CWD/state/STATUS.json') as f:
        s = json.load(f)
    name = s.get('project_name', '')
    if not name:
        print('## PM-Harness: セットアップ未完了')
        print('「セットアップして」と言ってプロジェクトを初期化してください。')
        sys.exit(0)
    print('## Current Status')
    print(f\"Project: {name}\")
    ptype = s.get('project_type', '')
    if ptype:
        print(f\"Type: {ptype}\")
    phase = s.get('current_phase', '')
    if phase:
        print(f\"Phase: {phase}\")
    print(f\"Updated: {s.get('last_updated', 'N/A')}\")
    ct = s.get('current_task')
    if ct:
        print(f\"Current Task: {ct}\")
    cn = s.get('context_notes')
    if cn:
        print(f\"Notes: {cn}\")
    if s.get('blockers'):
        print('Blockers: ' + ', '.join(str(b) for b in s['blockers']))
    if s.get('next_actions'):
        print('Next: ' + ', '.join(str(a) for a in s['next_actions'][:3]))
    oq = s.get('open_questions', [])
    if oq:
        aging = [q for q in oq if not q.get('resolved')]
        if aging:
            print(f\"Open Questions: {len(aging)} unresolved\")
except Exception as e:
    print(f'Warning: Failed to read STATUS.json: {e}', file=sys.stderr)
" 2>/dev/null || true

# --- ALERTS.json表示 ---
ALERTS="$CWD/state/ALERTS.json"
if [ -f "$ALERTS" ]; then
  python3 -c "
import json
try:
    a = json.load(open('$ALERTS'))
    rules = a.get('rule_alerts', [])
    llms = a.get('llm_alerts', [])
    if rules or llms:
        print()
        print('## Alerts')
        for r in rules:
            sev = '🔴' if r.get('severity') == 'high' else '🟡'
            print(f\"  {sev} [rule] {r.get('message', '')}\")
        for l in llms:
            sev = '🔴' if l.get('severity') == 'high' else '🟡'
            print(f\"  {sev} [llm] {l.get('message', '')}\")
except:
    pass
" 2>/dev/null || true
fi

# --- REVIEW_PROPOSALS表示 ---
PROPOSALS="$CWD/state/REVIEW_PROPOSALS.json"
if [ -f "$PROPOSALS" ]; then
  python3 -c "
import json
try:
    p = json.load(open('$PROPOSALS'))
    props = p.get('proposals', [])
    if props:
        print()
        print(f'## Harness Proposals ({len(props)}件)')
        print('context-reviewを実行して適用してください')
except:
    pass
" 2>/dev/null || true
fi

# --- 新しいworkspace/ファイルの通知 ---
if [ -d "$CWD/workspace" ]; then
  NEW_FILES=$(find "$CWD/workspace" -type f -mtime -1 2>/dev/null | head -5)
  if [ -n "$NEW_FILES" ]; then
    echo ""
    echo "## Recent workspace files (24h)"
    echo "$NEW_FILES" | while read f; do echo "  $(basename "$f")"; done
  fi
fi
