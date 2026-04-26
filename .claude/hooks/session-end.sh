#!/bin/bash
# SessionEnd で発火
# 1. transcript解析→SESSION_LOG充実  2. L1ルールFB  3. L2/L3起動判定
set -e

# stdinからcwdとtranscript_pathを取得
INPUT=$(cat)
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")

# --- 1. SESSION_LOG追記（transcript解析で充実化） ---
python3 -c "
import json, datetime, os

cwd = '$CWD'
transcript = '$TRANSCRIPT'
log_path = os.path.join(cwd, 'state/SESSION_LOG.json')

try:
    log = json.load(open(log_path)) if os.path.exists(log_path) else {'sessions': []}
except:
    log = {'sessions': []}

entry = {
    'timestamp': datetime.datetime.now().isoformat(),
    'session_id': os.environ.get('SESSION_ID', 'unknown'),
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
                    # スキル使用の検出
                    msg = obj.get('message', {})
                    content = msg.get('content', '')
                    if isinstance(content, str):
                        for skill in ['setup','context-pack','meeting-import','wbs-update',
                                      'risk-check','draft-update','context-sync','context-review',
                                      'cross-review','retro','weekly-report']:
                            if skill in content.lower():
                                skills.add(skill)
                    # ファイル編集の検出
                    tool_use = obj.get('tool_use', {})
                    if tool_use.get('name') in ('Edit', 'Write'):
                        fp = tool_use.get('input', {}).get('file_path', '')
                        if fp and ('/state/' in fp or '/docs/' in fp or '/meeting/' in fp or '/workspace/' in fp):
                            files.add(os.path.basename(fp))
                except:
                    pass
        entry['skills_used'] = list(skills)
        entry['files_modified'] = list(files)
    except:
        pass

log['sessions'].append(entry)

# ローテーション: 最新100件
if len(log['sessions']) > 100:
    log['sessions'] = log['sessions'][-100:]

with open(log_path, 'w') as f:
    json.dump(log, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true

# --- 2. L1: ルールベースFB（毎回） ---
RULES_SCRIPT="$CWD/.claude/hooks/project-advisor-rules.sh"
[ -f "$RULES_SCRIPT" ] && CLAUDE_PROJECT_DIR="$CWD" bash "$RULES_SCRIPT" 2>/dev/null || true

# --- 3. L2判定（24h経過チェック） ---
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

# L2/L3はagent hookでの実装を検討中。現在はログのみ。
if [ "$LLM_HOURS" -ge 24 ]; then
  echo "PM-Harness: L2 LLM FB due (${LLM_HOURS}h since last check)" > /dev/null
fi

# --- 4. L3判定（IMPROVEMENTS件数チェック） ---
ITEMS=$(python3 -c "
import json, os
f = os.path.join('$CWD', 'state/IMPROVEMENTS.json')
print(len(json.load(open(f)).get('items',[]))) if os.path.exists(f) else print(0)
" 2>/dev/null || echo "0")

if [ "$ITEMS" -ge 10 ]; then
  echo "PM-Harness: ${ITEMS} improvements pending. Run context-review." > /dev/null
fi
