#!/bin/bash
# PreToolUse(Edit|Write) で発火
# docs/ or state/ への変更を検知
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
  */state/*|*/docs/*)
    echo "PM-Harness: Modifying $FILE_PATH"
    exit 0  # Log mode. Block mode: exit 2
    ;;
  *)
    exit 0
    ;;
esac
