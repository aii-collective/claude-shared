#!/bin/bash
# auto-update.sh — Check for claude-shared updates on Claude Code launch.
#
# Compares local HEAD against remote HEAD. If they differ, pulls the latest.
# Uses a timestamp file to only check once per session (~every 30 minutes).
#
# Install: Add as a PreToolUse hook in ~/.claude/settings.json
# Part of claude-shared — https://github.com/aii-collective/claude-shared

# Allow the hook input through (we don't gate any tools)
cat > /dev/null

SHARED_DIR="${CLAUDE_SHARED_DIR:-$HOME/src/claude-shared}"
STAMP_FILE="/tmp/.claude-shared-update-stamp"
CHECK_INTERVAL=1800  # seconds between checks (30 min)

# --- Gate: skip if checked recently ---
if [ -f "$STAMP_FILE" ]; then
  LAST_CHECK=$(stat -f %m "$STAMP_FILE" 2>/dev/null || stat -c %Y "$STAMP_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  ELAPSED=$(( NOW - LAST_CHECK ))
  if [ "$ELAPSED" -lt "$CHECK_INTERVAL" ]; then
    exit 0
  fi
fi

# --- Check: compare local vs remote ---
cd "$SHARED_DIR" 2>/dev/null || exit 0

# Don't block if no remote configured
git remote | grep -q origin || exit 0

# Fetch remote (quiet, with timeout to avoid blocking)
timeout 5 git fetch origin main --quiet 2>/dev/null || exit 0

LOCAL_HEAD=$(git rev-parse HEAD 2>/dev/null)
REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null)

# Touch stamp regardless — we checked
touch "$STAMP_FILE"

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  exit 0
fi

# --- Update: pull latest ---
BEFORE_SHORT=$(git rev-parse --short HEAD)
git pull --ff-only origin main --quiet 2>/dev/null
AFTER_SHORT=$(git rev-parse --short HEAD)

if [ "$BEFORE_SHORT" != "$AFTER_SHORT" ]; then
  # Log the update (visible in Claude Code output)
  CHANGES=$(git log --oneline "$BEFORE_SHORT..$AFTER_SHORT" 2>/dev/null | head -5)
  echo "[claude-shared] Updated $BEFORE_SHORT → $AFTER_SHORT" >&2
  echo "$CHANGES" | sed 's/^/  /' >&2
  SHARED_UPDATED=true
else
  SHARED_UPDATED=false
fi

# --- Update submodule in current project if present ---
PROJECT_ROOT=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$PROJECT_ROOT" ] && [ -f "$PROJECT_ROOT/.gitmodules" ]; then
  if grep -q 'claude-shared' "$PROJECT_ROOT/.gitmodules" 2>/dev/null; then
    SUBMODULE_PATH=$(git -C "$PROJECT_ROOT" config --file .gitmodules --get-regexp 'submodule\..*claude.*\.path' 2>/dev/null | awk '{print $2}')
    if [ -n "$SUBMODULE_PATH" ] && [ -d "$PROJECT_ROOT/$SUBMODULE_PATH" ]; then
      SUB_BEFORE=$(git -C "$PROJECT_ROOT/$SUBMODULE_PATH" rev-parse --short HEAD 2>/dev/null)
      git -C "$PROJECT_ROOT" submodule update --remote "$SUBMODULE_PATH" --quiet 2>/dev/null
      SUB_AFTER=$(git -C "$PROJECT_ROOT/$SUBMODULE_PATH" rev-parse --short HEAD 2>/dev/null)
      if [ "$SUB_BEFORE" != "$SUB_AFTER" ]; then
        echo "[claude-shared] Submodule updated in $(basename "$PROJECT_ROOT"): $SUB_BEFORE → $SUB_AFTER" >&2
      fi
    fi
  fi
fi

exit 0
