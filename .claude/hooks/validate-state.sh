#!/bin/bash
# PostToolUse(Edit|Write) で発火
# state/*.jsonの変更のみ検査
set -e
CWD="${CLAUDE_CWD:-.}"

[ ! -d "$CWD/state" ] && exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except:
    print('')
" 2>/dev/null || echo "")

case "$FILE_PATH" in
  */state/*.json)
    if [ -f "$FILE_PATH" ]; then
      # JSON構文チェック
      python3 -c "import json; json.load(open('$FILE_PATH'))" 2>&1
      if [ $? -ne 0 ]; then
        echo "ERROR: $FILE_PATH is invalid JSON" >&2
        exit 2
      fi
      # CHANGELOG.json append-only確認
      case "$FILE_PATH" in
        */CHANGELOG.json)
          python3 -c "
import json, os
f = '$FILE_PATH'
bak = f + '.count'
current = len(json.load(open(f)).get('entries', []))
if os.path.exists(bak):
    prev = int(open(bak).read().strip())
    if current < prev:
        print(f'ERROR: CHANGELOG entries decreased ({prev} -> {current})')
        exit(2)
with open(bak, 'w') as b:
    b.write(str(current))
" 2>&1
          if [ $? -ne 0 ]; then
            exit 2
          fi
          ;;
      esac
    fi
    ;;
esac
exit 0
