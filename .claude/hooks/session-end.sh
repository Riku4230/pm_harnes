#!/bin/bash
# SessionEnd で発火
# 1. SESSION_LOG追記  2. session_handoff  3. L1ルールFB  4. L2/L3起動判定
set -e
CWD="${CLAUDE_CWD:-.}"

# --- 1. SESSION_LOG追記 ---
python3 -c "
import json, datetime, os
log_path = '$CWD/state/SESSION_LOG.json'
try:
    log = json.load(open(log_path)) if os.path.exists(log_path) else {'sessions': []}
except:
    log = {'sessions': []}
log['sessions'].append({
    'timestamp': datetime.datetime.now().isoformat(),
    'session_id': os.environ.get('SESSION_ID', 'unknown')
})
if len(log['sessions']) > 100:
    log['sessions'] = log['sessions'][-100:]
with open(log_path, 'w') as f:
    json.dump(log, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true

# --- 2. L1: ルールベースFB（毎回） ---
RULES_SCRIPT="$CWD/.claude/hooks/project-advisor-rules.sh"
[ -f "$RULES_SCRIPT" ] && bash "$RULES_SCRIPT" 2>/dev/null || true

# --- 3. L2: LLMプロジェクトFB（日次: 24h経過時のみ） ---
LLM_HOURS=$(python3 -c "
import json, os
from datetime import datetime
f='$CWD/state/ALERTS.json'
if os.path.exists(f):
    ts=json.load(open(f)).get('llm_checked','2000-01-01T00:00:00')
    print(int((datetime.now()-datetime.fromisoformat(ts)).total_seconds()/3600))
else:
    print(999)
" 2>/dev/null || echo "999")

if [ "$LLM_HOURS" -ge 24 ]; then
  LLM_SCRIPT="$CWD/.claude/hooks/project-advisor-llm.ts"
  [ -f "$LLM_SCRIPT" ] && npx ts-node "$LLM_SCRIPT" &
fi

# --- 4. L3: ハーネス自己改善（週次: 10件+3日 or 20件強制） ---
ITEMS=$(python3 -c "
import json, os
f='$CWD/state/IMPROVEMENTS.json'
print(len(json.load(open(f)).get('items',[]))) if os.path.exists(f) else print(0)
" 2>/dev/null || echo "0")

LAST_DAYS=$(python3 -c "
import json, os
from datetime import datetime
f='$CWD/state/REVIEW_PROPOSALS.json'
if os.path.exists(f):
    ts=json.load(open(f)).get('last_run','2000-01-01')
    print((datetime.now()-datetime.fromisoformat(ts)).days)
else:
    print(999)
" 2>/dev/null || echo "999")

if [ "$ITEMS" -ge 20 ] || ([ "$ITEMS" -ge 10 ] && [ "$LAST_DAYS" -ge 3 ]); then
  IMPROVE_SCRIPT="$CWD/.claude/hooks/self-improve.ts"
  [ -f "$IMPROVE_SCRIPT" ] && npx ts-node "$IMPROVE_SCRIPT" &
fi
