#!/bin/bash
# PM-Harness installer
# Usage: bash install.sh [--target /path/to/project] [--type personal|consulting|system_dev]
set -e

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR=""
PROJECT_TYPE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --type) PROJECT_TYPE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$TARGET_DIR" ]; then
  echo "PM-Harness Installer"
  echo "===================="
  echo ""
  read -p "Target project directory: " TARGET_DIR
fi

if [ -z "$PROJECT_TYPE" ]; then
  echo ""
  echo "Project type:"
  echo "  1) personal    - 日常・個人タスク（最小構成）"
  echo "  2) consulting  - コンサル・BPR・導入支援（フル構成）"
  echo "  3) system_dev  - システム開発（フル + SPEC + BACKLOG）"
  echo ""
  read -p "Select [1-3]: " TYPE_NUM
  case $TYPE_NUM in
    1) PROJECT_TYPE="personal" ;;
    2) PROJECT_TYPE="consulting" ;;
    3) PROJECT_TYPE="system_dev" ;;
    *) echo "Invalid selection"; exit 1 ;;
  esac
fi

TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")

echo ""
echo "Installing PM-Harness..."
echo "  Target: $TARGET_DIR"
echo "  Type:   $PROJECT_TYPE"
echo ""

# --- Backup existing files ---
safe_copy() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    local bak="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$dst" "$bak"
    echo "  Backed up: $dst -> $bak"
  fi
  cp "$src" "$dst"
}

# --- Create directories ---
mkdir -p "$TARGET_DIR/.claude/rules"
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/skills"
mkdir -p "$TARGET_DIR/docs"
mkdir -p "$TARGET_DIR/state"
mkdir -p "$TARGET_DIR/meeting"
mkdir -p "$TARGET_DIR/workspace"

# --- Rules (always overwrite) ---
echo "Installing rules..."
cp "$HARNESS_DIR/core/rules/"*.md "$TARGET_DIR/.claude/rules/"

# --- Hooks (always overwrite) ---
echo "Installing hooks..."
cp "$HARNESS_DIR/core/hooks/"*.sh "$TARGET_DIR/.claude/hooks/"
cp "$HARNESS_DIR/core/hooks/"*.ts "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
chmod +x "$TARGET_DIR/.claude/hooks/"*.sh

# --- Settings.json (merge if exists) ---
SETTINGS_DST="$TARGET_DIR/.claude/settings.json"
if [ -f "$SETTINGS_DST" ]; then
  echo "  settings.json exists. Merging hooks..."
  python3 -c "
import json
existing = json.load(open('$SETTINGS_DST'))
harness = json.load(open('$HARNESS_DIR/core/hooks/settings.json'))
if 'hooks' not in existing:
    existing['hooks'] = {}
for event, configs in harness['hooks'].items():
    existing['hooks'][event] = configs
with open('$SETTINGS_DST', 'w') as f:
    json.dump(existing, f, indent=2)
" 2>/dev/null || cp "$HARNESS_DIR/core/hooks/settings.json" "$SETTINGS_DST"
else
  cp "$HARNESS_DIR/core/hooks/settings.json" "$SETTINGS_DST"
fi

# --- Skills (always overwrite) ---
echo "Installing skills..."
for skill_dir in "$HARNESS_DIR/core/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$TARGET_DIR/.claude/skills/$skill_name"
  cp "$skill_dir"* "$TARGET_DIR/.claude/skills/$skill_name/" 2>/dev/null || true
done

# --- Templates (copy if missing) ---
echo "Installing templates ($PROJECT_TYPE)..."
TMPL_DIR="$HARNESS_DIR/templates/$PROJECT_TYPE"

# docs
for f in "$TMPL_DIR/docs/"*; do
  fname=$(basename "$f")
  dst="$TARGET_DIR/docs/$fname"
  if [ ! -f "$dst" ]; then
    cp "$f" "$dst"
    echo "  Created: docs/$fname"
  else
    echo "  Skipped: docs/$fname (exists)"
  fi
done

# state
for f in "$TMPL_DIR/state/"*; do
  fname=$(basename "$f")
  dst="$TARGET_DIR/state/$fname"
  if [ ! -f "$dst" ]; then
    cp "$f" "$dst"
    echo "  Created: state/$fname"
  else
    echo "  Skipped: state/$fname (exists)"
  fi
done

# --- CLAUDE.md (merge if exists) ---
CLAUDE_DST="$TARGET_DIR/CLAUDE.md"
if [ -f "$CLAUDE_DST" ]; then
  if grep -q "## PM-Harness" "$CLAUDE_DST" 2>/dev/null; then
    echo "  CLAUDE.md already has PM-Harness section. Skipping."
  else
    echo "  Appending PM-Harness section to existing CLAUDE.md..."
    echo "" >> "$CLAUDE_DST"
    cat "$HARNESS_DIR/templates/CLAUDE.md.template" >> "$CLAUDE_DST"
  fi
else
  cp "$HARNESS_DIR/templates/CLAUDE.md.template" "$CLAUDE_DST"
  echo "  Created: CLAUDE.md"
fi

echo ""
echo "PM-Harness installed successfully!"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR"
echo "  2. Edit CLAUDE.md to set project_name and project_type"
echo "  3. Edit docs/PROJECT.md with project details"
echo "  4. Run project-init skill to populate state/"
echo ""
echo "Or just start a Claude Code session — the harness will guide you."
