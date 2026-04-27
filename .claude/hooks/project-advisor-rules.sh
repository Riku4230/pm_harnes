#!/bin/bash
# L1: ルールベースプロジェクトFB（毎回、SessionEnd経由）
set -e
CWD="${CLAUDE_PROJECT_DIR:-.}"

python3 -c "
import json, os
from datetime import datetime

alerts = []
now = datetime.now()

# 1. 期限超過タスク検出
wbs = '$CWD/state/WBS.json'
if os.path.exists(wbs):
    try:
        tasks = json.load(open(wbs)).get('tasks', [])
        for t in tasks:
            if t.get('due') and t.get('status') != 'done':
                try:
                    due = datetime.fromisoformat(t['due'])
                    if due < now:
                        days = (now - due).days
                        alerts.append({
                            'type': 'overdue_task',
                            'severity': 'high' if days > 7 else 'medium',
                            'message': f\"タスク '{t.get('name')}' が{days}日超過\"
                        })
                except: pass
    except: pass

# 2. 対応策未定の高リスク
risk = '$CWD/state/RISK.json'
if os.path.exists(risk):
    try:
        risks = json.load(open(risk)).get('risks', [])
        for r in risks:
            if not r.get('mitigation') and r.get('impact') == 'high':
                alerts.append({
                    'type': 'unmitigated_risk',
                    'severity': 'high',
                    'message': f\"高リスク '{r.get('name')}' の対応策が未定義\"
                })
            if r.get('updated'):
                try:
                    if (now - datetime.fromisoformat(r['updated'])).days > 30:
                        alerts.append({
                            'type': 'stale_risk',
                            'severity': 'medium',
                            'message': f\"リスク '{r.get('name')}' が30日以上未更新\"
                        })
                except: pass
    except: pass

# 3. ステークホルダーへの長期未共有
cl = '$CWD/state/CHANGELOG.json'
if os.path.exists(cl):
    try:
        entries = json.load(open(cl)).get('entries', [])
        sh_entries = [e for e in entries if e.get('type') == 'stakeholder_update']
        if sh_entries:
            last = datetime.fromisoformat(sh_entries[-1]['date'])
            gap = (now - last).days
            if gap > 14:
                alerts.append({
                    'type': 'stale_communication',
                    'severity': 'medium',
                    'message': f'ステークホルダーへの共有が{gap}日間なし'
                })
    except: pass

# 4. Decision Drift検出
if os.path.exists(cl):
    try:
        entries = json.load(open(cl)).get('entries', [])
        decisions = [e for e in entries if e.get('type') == 'decision']
        status_path = '$CWD/state/STATUS.json'
        if decisions and os.path.exists(status_path):
            s = json.load(open(status_path))
            notes = str(s.get('context_notes', '')) + str(s.get('current_task', ''))
            for d in decisions[-5:]:
                desc = d.get('description', '')
                if d.get('scope') == 'non-goal' and desc and desc.lower() in notes.lower():
                    alerts.append({
                        'type': 'decision_drift',
                        'severity': 'medium',
                        'message': f\"Decision Drift: '{desc}' はnon-goalだが作業中に含まれている\"
                    })
    except: pass

# 5. Open Questions Aging
status_path = '$CWD/state/STATUS.json'
if os.path.exists(status_path):
    try:
        s = json.load(open(status_path))
        for q in s.get('open_questions', []):
            if q.get('resolved'):
                continue
            created = q.get('created')
            if created:
                age = (now - datetime.fromisoformat(created)).days
                if age > 7:
                    alerts.append({
                        'type': 'open_question_aging',
                        'severity': 'medium',
                        'message': f\"Open Question '{q.get('question', '?')}' が{age}日間未解決\"
                    })
                elif age > 3 and not q.get('owner'):
                    alerts.append({
                        'type': 'open_question_no_owner',
                        'severity': 'medium',
                        'message': f\"Open Question '{q.get('question', '?')}' にowner未設定({age}日)\"
                    })
    except: pass

# 6. Source-of-Truth整合性
if os.path.exists(status_path) and os.path.exists(wbs):
    try:
        s = json.load(open(status_path))
        w = json.load(open(wbs))
        task_ids = set()
        for t in w.get('tasks', []):
            if t.get('id'): task_ids.add(t['id'])
            if t.get('name'): task_ids.add(t['name'])
            for st in t.get('subtasks', []):
                if st.get('id'): task_ids.add(st['id'])
                if st.get('name'): task_ids.add(st['name'])
        ct = s.get('current_task')
        if ct and task_ids and ct not in task_ids:
            alerts.append({
                'type': 'source_of_truth',
                'severity': 'medium',
                'message': f\"STATUS.current_task '{ct}' がWBS.jsonに存在しない\"
            })
        for na in s.get('next_actions', []):
            if task_ids and na not in task_ids:
                alerts.append({
                    'type': 'source_of_truth',
                    'severity': 'low',
                    'message': f\"STATUS.next_actions '{na}' がWBS.jsonに存在しない\"
                })
    except: pass

# 7. IMPROVEMENTS蓄積チェック
imp = '$CWD/state/IMPROVEMENTS.json'
if os.path.exists(imp):
    try:
        count = len(json.load(open(imp)).get('items', []))
        if count >= 10:
            alerts.append({
                'type': 'improvements_backlog',
                'severity': 'low',
                'message': f'IMPROVEMENTS.jsonに{count}件蓄積。context-reviewを実行してください'
            })
    except: pass

# 書き出し（既存llm_alertsは保持）
alerts_path = '$CWD/state/ALERTS.json'
existing = {}
if os.path.exists(alerts_path):
    try: existing = json.load(open(alerts_path))
    except: pass

existing['rule_alerts'] = alerts
existing['rule_checked'] = now.isoformat()

with open(alerts_path, 'w') as f:
    json.dump(existing, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true
