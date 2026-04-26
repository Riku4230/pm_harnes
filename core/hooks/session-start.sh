#!/bin/bash
# SessionStart で発火
# git pull → 差分表示 → STATUS要約 → ALERTS → PROPOSALS → workspace新着
set -e

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

# --- Git Pull + Schedule更新の差分表示 ---
cd "$CWD"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  # リモートがあればpull
  if git remote get-url origin > /dev/null 2>&1; then
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
    git pull --ff-only origin main > /dev/null 2>&1 || true
    AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")

    if [ -n "$BEFORE" ] && [ -n "$AFTER" ] && [ "$BEFORE" != "$AFTER" ]; then
      # scheduleによる更新があった
      COMMIT_COUNT=$(git rev-list --count "$BEFORE".."$AFTER" 2>/dev/null || echo "0")
      echo "## Updates since last session ($COMMIT_COUNT commits)"
      echo ""

      # 変更されたファイルを表示
      CHANGED=$(git diff --name-only "$BEFORE".."$AFTER" 2>/dev/null || echo "")
      if [ -n "$CHANGED" ]; then
        # sources/の新着
        SOURCES_NEW=$(echo "$CHANGED" | grep "^sources/" || true)
        if [ -n "$SOURCES_NEW" ]; then
          SOURCE_COUNT=$(echo "$SOURCES_NEW" | wc -l | tr -d ' ')
          echo "📥 source-sync: ${SOURCE_COUNT}件の新しい情報"
          echo "$SOURCES_NEW" | head -5 | while read f; do echo "  - $f"; done
          [ "$SOURCE_COUNT" -gt 5 ] && echo "  ... and $(($SOURCE_COUNT - 5)) more"
          echo ""
        fi

        # workspace/の新着（weekly-report, retro等）
        WORKSPACE_NEW=$(echo "$CHANGED" | grep "^workspace/" || true)
        if [ -n "$WORKSPACE_NEW" ]; then
          echo "📝 新しいレポート:"
          echo "$WORKSPACE_NEW" | while read f; do echo "  - $f"; done
          echo ""
        fi

        # state/の更新
        STATE_UPDATED=$(echo "$CHANGED" | grep "^state/" || true)
        if [ -n "$STATE_UPDATED" ]; then
          echo "🔄 state更新:"
          echo "$STATE_UPDATED" | while read f; do echo "  - $f"; done
          echo ""
        fi

        # コミットメッセージ
        echo "コミット履歴:"
        git log --oneline "$BEFORE".."$AFTER" 2>/dev/null | head -5
        echo ""
      fi
    fi
  fi
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
        print('retroを実行して適用してください')
except:
    pass
" 2>/dev/null || true
fi
