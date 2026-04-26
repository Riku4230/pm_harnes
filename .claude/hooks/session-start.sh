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
        lines.append(f"[{name}]")
        if s.get("current_task"):
            lines.append(f"  doing: {s['current_task']}")
        na = s.get("next_actions", [])
        if na:
            lines.append(f"  TODO({len(na)}):")
            for a in na[:5]:
                lines.append(f"    - {a}")
except:
    lines.append("PM-Harness: status error")

try:
    a = json.load(open(os.path.join(cwd, "state/ALERTS.json")))
    rule_alerts = a.get("rule_alerts", [])
    llm_alerts = a.get("llm_alerts", [])
    high = []
    warn = []
    for r in rule_alerts:
        msg = r.get("message") or r.get("title") or ""
        cat = r.get("type", "")
        if msg:
            label = f"[{cat}] {msg}" if cat else msg
            if r.get("severity") == "high":
                high.append(label)
            else:
                warn.append(label)
    for l in llm_alerts:
        msg = l.get("message") or l.get("title") or ""
        cat = l.get("category", "")
        if msg:
            label = f"[{cat}] {msg}" if cat else msg
            if l.get("severity") == "high":
                high.append(label)
            else:
                warn.append(label)
    if high:
        lines.append(f"  RISK({len(high)}):")
        for h in high[:3]:
            lines.append(f"    {h}")
    if warn:
        lines.append(f"  NOTE({len(warn)}):")
        for w in warn[:3]:
            lines.append(f"    {w}")
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
