#!/bin/bash
# SessionStart で発火
# systemMessage JSONで出力 → ユーザーのターミナルに表示、コンテキスト圧迫なし
set -e

CWD="${CLAUDE_PROJECT_DIR:-.}"

[ ! -d "$CWD/state" ] && exit 0
[ ! -f "$CWD/state/STATUS.json" ] && exit 0

# --- git pull ---
GIT_UPDATE=""
cd "$CWD"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if git remote get-url origin > /dev/null 2>&1; then
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
    git pull --ff-only origin main > /dev/null 2>&1 || true
    AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -n "$BEFORE" ] && [ -n "$AFTER" ] && [ "$BEFORE" != "$AFTER" ]; then
      COUNT=$(git rev-list --count "$BEFORE".."$AFTER" 2>/dev/null || echo "0")
      GIT_UPDATE="updates: ${COUNT} commits from remote"
    fi
  fi
fi

# --- 情報収集してsystemMessage出力 ---
export GIT_UPDATE
python3 << 'PYEOF'
import json, os, sys

cwd = os.environ.get("CLAUDE_PROJECT_DIR", ".")
lines = []

git_update = os.environ.get("GIT_UPDATE", "")
if git_update:
    lines.append(git_update)

try:
    s = json.load(open(os.path.join(cwd, "state/STATUS.json")))
    name = s.get("project_name", "")
    if not name:
        lines.append("PM-Harness: setup required")
    else:
        parts = [name]
        if s.get("current_phase"):
            parts.append(s["current_phase"])
        lines.append(" / ".join(parts))
        if s.get("current_task"):
            lines.append(f"  task: {s['current_task']}")
        if s.get("next_actions"):
            lines.append(f"  next: {', '.join(str(a) for a in s['next_actions'][:3])}")
except:
    lines.append("PM-Harness: status error")

try:
    a = json.load(open(os.path.join(cwd, "state/ALERTS.json")))
    for r in a.get("rule_alerts", []):
        sev = "!!" if r.get("severity") == "high" else "!"
        lines.append(f"  {sev} {r.get('message', '')}")
    for l in a.get("llm_alerts", []):
        sev = "!!" if l.get("severity") == "high" else "!"
        lines.append(f"  {sev} {l.get('message', '')}")
except:
    pass

try:
    p = json.load(open(os.path.join(cwd, "state/REVIEW_PROPOSALS.json")))
    props = p.get("proposals", [])
    if props:
        lines.append(f"  proposals: {len(props)} pending")
except:
    pass

msg = "\n".join(lines)
print(json.dumps({"systemMessage": msg}))
PYEOF
