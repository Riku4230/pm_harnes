#!/bin/bash
# PreToolUse(Edit|Write|apply_patch) で発火
# .claude/配下への変更を制御:
#   rules/ → WARNING（context-reviewでの編集を許可するため）
#   skills/, hooks/ → BLOCK（別ブランチ+PR or Bash経由で）
set -e

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    inp = json.load(sys.stdin)
    ti = inp.get('tool_input', {})
    # apply_patch: パッチ本文からファイルパスを抽出
    if inp.get('tool_name') == 'apply_patch':
        patch = ti.get('patch', '')
        for line in patch.split(chr(10)):
            if line.startswith('*** Update File:') or line.startswith('*** Add File:'):
                print(line.split(':', 1)[1].strip())
                break
        else:
            print('')
    else:
        print(ti.get('file_path', ''))
except:
    print('')
" 2>/dev/null || echo "")

case "$FILE_PATH" in
  */.claude/rules/*|*/.codex/*)
    echo "PM-Harness: WARNING — ハーネスルール編集: $FILE_PATH （context-reviewスキル経由を推奨）" >&2
    exit 0
    ;;
  */.claude/skills/*|*/.claude/hooks/*|*/.claude/settings.json)
    echo "PM-Harness: BLOCKED — ハーネスインフラの直接編集は禁止です（Bash経由 or 別ブランチ+PRで）: $FILE_PATH" >&2
    exit 2
    ;;
  */state/*|*/docs/*)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
