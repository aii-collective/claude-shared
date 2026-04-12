#!/bin/bash
# setup.sh — Link claude-shared skills, hooks, and rules into a target project.
#
# Usage:
#   /path/to/claude-shared/setup.sh [target-project-dir]
#
# If target-project-dir is omitted, uses the current directory.

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "claude-shared setup"
echo "  Shared repo: $SHARED_DIR"
echo "  Target:      $TARGET_DIR"
echo ""

# --- Create directories ---
mkdir -p "$TARGET_DIR/.claude/skills"
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/rules"

# --- Symlink skills ---
SKILL_LINK="$TARGET_DIR/.claude/skills/document-commit"
if [ -L "$SKILL_LINK" ]; then
  echo "  [skip] skills/document-commit (symlink already exists)"
elif [ -e "$SKILL_LINK" ]; then
  echo "  [warn] skills/document-commit exists but is not a symlink — skipping"
  echo "         Remove it manually if you want to use the shared version"
else
  ln -s "$SHARED_DIR/skills/document-commit" "$SKILL_LINK"
  echo "  [link] skills/document-commit -> $SHARED_DIR/skills/document-commit"
fi

# --- Symlink hooks ---
for HOOK in require-commit-doc.sh update-design-doc.sh; do
  HOOK_LINK="$TARGET_DIR/.claude/hooks/$HOOK"
  if [ -L "$HOOK_LINK" ]; then
    echo "  [skip] hooks/$HOOK (symlink already exists)"
  elif [ -e "$HOOK_LINK" ]; then
    echo "  [warn] hooks/$HOOK exists but is not a symlink — skipping"
    echo "         Remove it manually if you want to use the shared version"
  else
    ln -s "$SHARED_DIR/hooks/$HOOK" "$HOOK_LINK"
    echo "  [link] hooks/$HOOK -> $SHARED_DIR/hooks/$HOOK"
  fi
done

# --- Symlink rules ---
RULES_LINK="$TARGET_DIR/.claude/rules/doc-workflow.md"
if [ -L "$RULES_LINK" ]; then
  echo "  [skip] rules/doc-workflow.md (symlink already exists)"
elif [ -e "$RULES_LINK" ]; then
  echo "  [warn] rules/doc-workflow.md exists but is not a symlink — skipping"
else
  ln -s "$SHARED_DIR/rules/doc-workflow.md" "$RULES_LINK"
  echo "  [link] rules/doc-workflow.md -> $SHARED_DIR/rules/doc-workflow.md"
fi

# --- settings.json hook configuration ---
SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
HOOK_CONFIG='{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/require-commit-doc.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/update-design-doc.sh"
          }
        ]
      }
    ]
  }
}'

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "$HOOK_CONFIG" > "$SETTINGS_FILE"
  echo "  [create] settings.json with hook configuration"
else
  # Check if hooks are already configured
  if jq -e '.hooks.PreToolUse' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "  [skip] settings.json already has hooks configured"
    echo "         Review manually to ensure hook paths are correct"
  else
    # Merge hooks into existing settings
    MERGED=$(jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$HOOK_CONFIG"))
    echo "$MERGED" > "$SETTINGS_FILE"
    echo "  [merge] Added hook configuration to existing settings.json"
  fi
fi

# --- Install auto-update hook in user-level settings ---
USER_SETTINGS="$HOME/.claude/settings.json"
AUTO_UPDATE_HOOK="$SHARED_DIR/hooks/auto-update.sh"

if [ -f "$USER_SETTINGS" ]; then
  if grep -q "auto-update.sh" "$USER_SETTINGS" 2>/dev/null; then
    echo "  [skip] Auto-update hook already in ~/.claude/settings.json"
  else
    # Merge auto-update hook into user settings
    AUTO_HOOK_CONFIG=$(cat <<AUTOHOOK
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\$HOME/src/claude-shared/hooks/auto-update.sh"
          }
        ]
      }
    ]
  }
}
AUTOHOOK
)
    MERGED=$(jq -s 'def merge_hooks: if .[0].hooks.PreToolUse then .[0] * {hooks: {PreToolUse: (.[0].hooks.PreToolUse + .[1].hooks.PreToolUse)}} else .[0] * .[1] end; merge_hooks' "$USER_SETTINGS" <(echo "$AUTO_HOOK_CONFIG"))
    echo "$MERGED" > "$USER_SETTINGS"
    echo "  [merge] Added auto-update hook to ~/.claude/settings.json"
  fi
else
  mkdir -p "$HOME/.claude"
  cat > "$USER_SETTINGS" <<AUTOHOOK
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\$HOME/src/claude-shared/hooks/auto-update.sh"
          }
        ]
      }
    ]
  }
}
AUTOHOOK
  echo "  [create] ~/.claude/settings.json with auto-update hook"
fi

# --- Create docs directories if they don't exist ---
echo ""
if [ ! -d "$TARGET_DIR/docs/versions" ]; then
  echo "  [note] docs/versions/ does not exist yet."
  echo "         Create it when you're ready: mkdir -p docs/versions docs/designs docs/plans"
else
  echo "  [ok] docs/versions/ exists"
fi

echo ""
echo "Done! The documentation-first workflow is now linked."
echo "Auto-update is enabled — claude-shared will stay current on every Claude Code launch."
echo ""
echo "Next steps:"
echo "  1. Create docs directories if needed:  mkdir -p docs/versions docs/designs docs/plans"
echo "  2. Create an architecture doc:          docs/designs/architecture.md"
echo "  3. Create your first design doc:        docs/designs/v0.1.md"
echo "  4. Start Claude Code and try:           /document-commit"
