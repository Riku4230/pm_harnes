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
                lines.append(f"  TODO({len(active_parent)}):")

                for t in active_parent[:5]:
                    due = t.get("due", "")
                    due_str = f" (~{due[5:]})" if due else ""

                    deps_str = ""
                    if t.get("dependencies"):
                        deps_str = " <- " + ", ".join(t["dependencies"])

                    status_mark = {"in_progress": "*", "blocked": "!", "not_started": " "}.get(t.get("status", ""), " ")
                    lines.append(f"   [{status_mark}] {t['name']}{due_str}{deps_str}")

                    # サブタスク展開: 進行中 or 依存が全完了の次タスク
                    deps_all_done = all(task_by_name.get(d, {}).get("status") == "done" for d in t.get("dependencies", []))
                    if t.get("status") == "in_progress" or (t.get("status") == "not_started" and deps_all_done):
                        subs = [st for st in t.get("subtasks", []) if st.get("status") != "done"]
                        subs.sort(key=lambda x: x.get("due", "9999-12-31"))
                        for sub in subs[:3]:
                            sub_due = sub.get("due", "")
                            sub_mark = {"in_progress": "*", "blocked": "!", "not_started": " "}.get(sub.get("status", ""), " ")
                            lines.append(f"      [{sub_mark}] {sub.get('name', '')} ({sub_due})")
                        if len(subs) > 3:
                            lines.append(f"       +{len(subs)-3}more")
                if len(active_parent) > 5:
                    lines.append(f"   +{len(active_parent)-5}more")

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
    alerts_path = os.path.join(cwd, "state/ALERTS.json")
    a = json.load(open(alerts_path))
    rule_alerts = a.get("rule_alerts", [])
    llm_alerts = a.get("llm_alerts", [])
    high = []
    warn = []
    l2_items = []

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
        if msg:
            cat = l.get("category", "")
            severity = l.get("severity", "")
            prefix = "/".join([x for x in [severity, cat] if x])
            label = f"[{prefix}] {msg}" if prefix else msg
            suggestion = (
                l.get("suggestion")
                or l.get("recommended_action")
                or l.get("action")
                or l.get("fix")
            )
            l2_items.append((label, suggestion))

    if high:
        lines.append(f"  RISK({len(high)}):")
        for h in high[:3]:
            lines.append(f"    {h}")
    if warn:
        lines.append(f"  NOTE({len(warn)}):")
        for w in warn[:3]:
            lines.append(f"    {w}")
    if l2_items:
        llm_checked = a.get("llm_checked")
        displayed_llm_checked = a.get("displayed_llm_checked")
        label = "NEW L2" if llm_checked and llm_checked != displayed_llm_checked else "L2"
        lines.append(f"  {label}({len(l2_items)}):")
        for msg, suggestion in l2_items[:3]:
            lines.append(f"    {msg}")
            if suggestion:
                lines.append(f"      -> {suggestion}")
        if len(l2_items) > 3:
            lines.append(f"    +{len(l2_items)-3}more")
    if a.get("llm_checked") and a.get("displayed_llm_checked") != a.get("llm_checked"):
        a["displayed_llm_checked"] = a["llm_checked"]
        try:
            with open(alerts_path, "w") as f:
                json.dump(a, f, ensure_ascii=False, indent=2)
                f.write("\n")
        except:
            pass
except:
    pass

# PROPOSALS
try:
    proposals_path = os.path.join(cwd, "state/REVIEW_PROPOSALS.json")
    p = json.load(open(proposals_path))
    props = p.get("proposals", [])
    if props:
        last_run = p.get("last_run")
        displayed_last_run = p.get("displayed_last_run")
        label = "NEW L3 PROPOSALS" if last_run and last_run != displayed_last_run else "L3 PROPOSALS"
        lines.append(f"  {label}({len(props)}):")
        for item in props[:3]:
            if isinstance(item, str):
                lines.append(f"    {item}")
                continue

            category = item.get("category") or item.get("type") or item.get("layer") or ""
            title = (
                item.get("title")
                or item.get("name")
                or item.get("summary")
                or item.get("message")
                or str(item)
            )
            prefix = f"[{category}] " if category else ""
            lines.append(f"    {prefix}{title}")

            recommendation = (
                item.get("recommendation")
                or item.get("suggestion")
                or item.get("action")
                or item.get("fix")
            )
            if recommendation:
                lines.append(f"      -> {recommendation}")
        if len(props) > 3:
            lines.append(f"    +{len(props)-3}more")
    if p.get("last_run") and p.get("displayed_last_run") != p.get("last_run"):
        p["displayed_last_run"] = p["last_run"]
        try:
            with open(proposals_path, "w") as f:
                json.dump(p, f, ensure_ascii=False, indent=2)
                f.write("\n")
        except:
            pass
except:
    pass

msg = "\n".join(lines)
print(json.dumps({"systemMessage": msg}))
PYEOF
