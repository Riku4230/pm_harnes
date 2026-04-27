#!/bin/bash
# SessionStart で発火
# systemMessage JSONで出力 → ユーザーのターミナルに表示、コンテキスト圧迫なし
set -e

CWD="${CLAUDE_PROJECT_DIR:-.}"

[ ! -d "$CWD/state" ] && exit 0
[ ! -f "$CWD/state/STATUS.json" ] && exit 0

# --- git pull + 差分取得 ---
GIT_UPDATE=""
GIT_COMMITS=""
cd "$CWD"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if git remote get-url origin > /dev/null 2>&1; then
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
    git pull --ff-only origin main > /dev/null 2>&1 || true
    AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -n "$BEFORE" ] && [ -n "$AFTER" ] && [ "$BEFORE" != "$AFTER" ]; then
      GIT_UPDATE="true"
      GIT_COMMITS=$(git log --oneline "$BEFORE".."$AFTER" 2>/dev/null | head -5)
    fi
  fi
fi

# --- 情報収集してsystemMessage出力 ---
export GIT_UPDATE GIT_COMMITS
python3 << 'PYEOF'
import json, os, sys
from datetime import datetime

cwd = os.environ.get("CLAUDE_PROJECT_DIR", ".")
lines = []
today = datetime.now().strftime("%Y-%m-%d")

# git更新
git_update = os.environ.get("GIT_UPDATE", "")
git_commits = os.environ.get("GIT_COMMITS", "")
if git_update and git_commits:
    lines.append("SYNC:")
    for c in git_commits.strip().split("\n"):
        if c.strip():
            lines.append(f"  {c.strip()}")
    lines.append("")

try:
    s = json.load(open(os.path.join(cwd, "state/STATUS.json")))
    name = s.get("project_name", "")
    if not name:
        lines.append("PM-Harness: setup required")
    else:
        lines.append(f"[{name}]")
        if s.get("current_task"):
            lines.append(f"  doing: {s['current_task']}")

        # WBSからTODO + 期限超過
        try:
            wbs = json.load(open(os.path.join(cwd, "state/WBS.json")))
            tasks = [t for t in wbs.get("tasks", []) if t.get("status") != "done"]
            tasks.sort(key=lambda t: t.get("due", "9999-12-31"))

            overdue = [t for t in tasks if t.get("due") and t["due"] < today]
            upcoming = [t for t in tasks if not (t.get("due") and t["due"] < today)]

            if overdue:
                lines.append(f"  OVERDUE({len(overdue)}):")
                for t in overdue[:3]:
                    days = (datetime.now() - datetime.strptime(t["due"], "%Y-%m-%d")).days
                    lines.append(f"    - {t.get('name')} ({t['due']}) +{days}日超過")

            if upcoming:
                lines.append(f"  TODO({len(upcoming)}):")
                for t in upcoming[:5]:
                    due = t.get("due", "")
                    lines.append(f"    - {t.get('name')} ({due})" if due else f"    - {t.get('name')}")
        except:
            na = s.get("next_actions", [])
            if na:
                lines.append(f"  TODO({len(na)}):")
                for a in na[:5]:
                    lines.append(f"    - {a}")

        # Open Questions
        oq = [q for q in s.get("open_questions", []) if not q.get("resolved")]
        if oq:
            lines.append(f"  Q({len(oq)}):")
            for q in oq[:3]:
                qtext = q.get("question", "")
                created = q.get("created", "")
                if created:
                    try:
                        days = (datetime.now() - datetime.strptime(created, "%Y-%m-%d")).days
                        lines.append(f"    - {qtext} ({days}日)")
                    except:
                        lines.append(f"    - {qtext}")
                else:
                    lines.append(f"    - {qtext}")

except:
    lines.append("PM-Harness: status error")

# ALERTS
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

# PROPOSALS
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
