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

        # WBSからTODO（親子+依存関係表示）
        try:
            wbs = json.load(open(os.path.join(cwd, "state/WBS.json")))
            tasks = wbs.get("tasks", [])
            task_by_name = {t["name"]: t for t in tasks if t.get("name")}

            overdue_parent = []
            active_parent = []
            for t in tasks:
                if t.get("status") == "done":
                    continue
                if t.get("due") and t["due"] < today:
                    overdue_parent.append(t)
                else:
                    active_parent.append(t)

            overdue_parent.sort(key=lambda t: t.get("due", "9999-12-31"))
            active_parent.sort(key=lambda t: t.get("due", "9999-12-31"))

            if overdue_parent:
                lines.append(f"  OVERDUE({len(overdue_parent)}):")
                for t in overdue_parent[:3]:
                    days = (datetime.now() - datetime.strptime(t["due"], "%Y-%m-%d")).days
                    deps_str = ""
                    if t.get("dependencies"):
                        deps_str = " <- " + ", ".join(t["dependencies"])
                    lines.append(f"    - {t['name']} ({t['due']}) +{days}d{deps_str}")

            if active_parent:
                # 未完了の親タスク数を表示
                total_subs = sum(len([st for st in t.get("subtasks", []) if st.get("status") != "done"]) for t in active_parent)
                count_label = f"{len(active_parent)}tasks"
                if total_subs:
                    count_label += f", {total_subs}subs"
                lines.append(f"  TODO({count_label}):")

                for t in active_parent[:5]:
                    start = t.get("start_date", "")
                    due = t.get("due", "")
                    period = ""
                    if start and due:
                        period = f" ({start[5:]}-{due[5:]})"
                    elif due:
                        period = f" (~{due[5:]})"

                    # 依存関係
                    deps_str = ""
                    if t.get("dependencies"):
                        dep_statuses = []
                        for d in t["dependencies"]:
                            dep_t = task_by_name.get(d, {})
                            st = dep_t.get("status", "?")
                            mark = "x" if st == "done" else "o" if st == "in_progress" else "."
                            dep_statuses.append(f"{mark}{d}")
                        deps_str = " <- " + ", ".join(dep_statuses)

                    status_mark = {"in_progress": "*", "blocked": "!", "not_started": " "}.get(t.get("status", ""), " ")
                    lines.append(f"   [{status_mark}] {t['name']}{period}{deps_str}")

                    # サブタスク（最大3件）
                    subs = [st for st in t.get("subtasks", []) if st.get("status") != "done"]
                    subs.sort(key=lambda x: x.get("due", "9999-12-31"))
                    for sub in subs[:3]:
                        sub_due = sub.get("due", "")
                        sub_dep = ""
                        if sub.get("depends_on"):
                            sub_dep = " <- " + ", ".join(sub["depends_on"])
                        sub_mark = {"in_progress": "*", "blocked": "!", "not_started": " "}.get(sub.get("status", ""), " ")
                        lines.append(f"      [{sub_mark}] {sub.get('name', '')} ({sub_due}){sub_dep}")
                    if len(subs) > 3:
                        lines.append(f"       ... +{len(subs)-3}more")

        except:
            na = s.get("next_actions", [])
            if na:
                lines.append(f"  TODO({len(na)}):")
                for a in na[:5]:
                    lines.append(f"    - {a}")

        # Open Questions
        try:
            raw_oq = s.get("open_questions", [])
            oq = []
            for q in raw_oq:
                if isinstance(q, str):
                    oq.append(q)
                elif isinstance(q, dict) and not q.get("resolved"):
                    oq.append(q.get("question", str(q)))
            if oq:
                lines.append(f"  OpenQuestion({len(oq)}):")
                for q in oq[:3]:
                    lines.append(f"    - {q}")
        except:
            pass

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
