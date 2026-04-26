#!/bin/bash
# PreToolUse(Edit|Write) で発火
# state/ または docs/ への変更を検知
# RISK.json/CHANGELOG.jsonへの書き込みはログ表示
# .claude/rules/ や .claude/skills/ への直接書き込みはブロック（context-review経由で行う）
set -e

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except:
    print('')
" 2>/dev/null || echo "")

case "$FILE_PATH" in
  */.claude/rules/*|*/.claude/skills/*|*/.claude/hooks/*|*/.claude/policies/*|*/.claude/personas/*)
    echo "PM-Harness: BLOCKED — ハーネスファイルの直接編集はcontext-reviewスキルで行ってください: $FILE_PATH" >&2
    exit 2
    ;;
  */state/*|*/docs/*)
    echo "PM-Harness: Modifying $FILE_PATH"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
