#!/bin/bash
# SessionEnd で発火（セッション終了時のみ、1回/セッション）
# 1. transcript解析→SESSION_LOG充実  2. L1ルールFB  3. L2/L3判定表示
set -e

# stdinからセッション情報を取得
INPUT=$(cat)
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null || echo "unknown")

# --- 1. SESSION_LOG追記（transcript解析で充実化） ---
python3 -c "
import json, datetime, os

cwd = '$CWD'
transcript = '$TRANSCRIPT'
session_id = '$SESSION_ID'
log_path = os.path.join(cwd, 'state/SESSION_LOG.json')

if not os.path.isdir(os.path.join(cwd, 'state')):
    exit(0)

try:
    log = json.load(open(log_path)) if os.path.exists(log_path) else {'sessions': []}
except:
    log = {'sessions': []}

entry = {
    'timestamp': datetime.datetime.now().isoformat(),
    'session_id': session_id,
    'skills_used': [],
    'files_modified': [],
    'decisions': []
}

# transcript_pathからセッション情報を抽出
if transcript and os.path.exists(transcript):
    try:
        skills = set()
        files = set()
        with open(transcript) as f:
            for line in f:
                try:
                    obj = json.loads(line.strip())
                    msg = obj.get('message', {})
                    content = msg.get('content', '')
                    if isinstance(content, str):
                        for skill in ['setup','source-sync','meeting-import','wbs-update',
                                      'risk-check','draft-update','doc-check','context-review',
                                      'cross-review','retro','weekly-report','decompose']:
                            if f'/{skill}' in content or f'skill: \"{skill}\"' in content.lower():
                                skills.add(skill)
                    if isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict):
                                text = block.get('text', '')
                                if isinstance(text, str):
                                    for skill in ['setup','source-sync','meeting-import','wbs-update',
                                                  'risk-check','draft-update','doc-check','context-review',
                                                  'cross-review','retro','weekly-report','decompose']:
                                        if f'/{skill}' in text:
                                            skills.add(skill)
                    if isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get('type') == 'tool_use':
                                name = block.get('name', '')
                                inp = block.get('input', {})
                                if name in ('Edit', 'Write'):
                                    fp = inp.get('file_path', '')
                                    if fp and ('/state/' in fp or '/docs/' in fp or '/meeting/' in fp or '/workspace/' in fp):
                                        files.add(os.path.basename(fp))
                    tool_use = obj.get('tool_use', {})
                    if tool_use.get('name') in ('Edit', 'Write'):
                        fp = tool_use.get('input', {}).get('file_path', '')
                        if fp and ('/state/' in fp or '/docs/' in fp or '/meeting/' in fp or '/workspace/' in fp):
                            files.add(os.path.basename(fp))
                except:
                    pass
        entry['skills_used'] = sorted(skills)
        entry['files_modified'] = sorted(files)
    except:
        pass

# CHANGELOG.jsonから当日の決定事項を抽出
cl_path = os.path.join(cwd, 'state/CHANGELOG.json')
if os.path.exists(cl_path):
    try:
        today = datetime.date.today().isoformat()
        entries = json.load(open(cl_path)).get('entries', [])
        for e in entries:
            if e.get('date') == today and e.get('type') == 'decision':
                entry['decisions'].append(e.get('description', ''))
    except:
        pass

log['sessions'].append(entry)

if len(log['sessions']) > 50:
    log['sessions'] = log['sessions'][-50:]

with open(log_path, 'w') as f:
    json.dump(log, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true

# --- 2. L1: ルールベースFB（毎回） ---
RULES_SCRIPT="$CWD/.claude/hooks/project-advisor-rules.sh"
[ -f "$RULES_SCRIPT" ] && CLAUDE_PROJECT_DIR="$CWD" bash "$RULES_SCRIPT" 2>/dev/null || true

# --- 3. L2判定（表示のみ、実行はstop-advisor.sh） ---
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
  echo "PM-Harness: L2 LLM FB due (${LLM_HOURS}h since last check)" > /dev/null
fi

# --- 4. L3判定（表示のみ） ---
ITEMS=$(python3 -c "
import json, os
f = os.path.join('$CWD', 'state/IMPROVEMENTS.json')
print(len(json.load(open(f)).get('items',[]))) if os.path.exists(f) else print(0)
" 2>/dev/null || echo "0")

if [ "$ITEMS" -ge 10 ]; then
  echo "PM-Harness: ${ITEMS} improvements pending. Run context-review." > /dev/null
fi
