#!/bin/bash
# PreToolUse hook: deny git commit if no docs/versions/ file is staged.
# Forces Claude to run /document-commit first to generate the implementation doc.
#
# Part of claude-shared — https://github.com/aii-collective/claude-shared

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git commit commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit\b'; then
  exit 0
fi

# If the project doesn't use docs/versions/, skip enforcement
if [ ! -d "docs/versions" ]; then
  exit 0
fi

# Check if any file in docs/versions/ is staged
if git diff --cached --name-only | grep -q '^docs/versions/'; then
  exit 0  # Doc is staged, allow the commit
fi

# Count how many commits are undocumented (since last documented commit)
LAST_DOC_HASH=""
LATEST_DOC=$(ls -1 docs/versions/*.md 2>/dev/null | sort -t_ -k1 -n | tail -1)
if [ -n "$LATEST_DOC" ]; then
  # Extract hash from filename like 1_68cbf20.md
  LAST_DOC_HASH=$(basename "$LATEST_DOC" .md | sed 's/^[0-9]*_//')
fi

UNDOCUMENTED_COUNT=0
if [ -n "$LAST_DOC_HASH" ] && git rev-parse "$LAST_DOC_HASH" >/dev/null 2>&1; then
  UNDOCUMENTED_COUNT=$(git rev-list "$LAST_DOC_HASH"..HEAD --count 2>/dev/null || echo 0)
else
  UNDOCUMENTED_COUNT=$(git rev-list HEAD --count 2>/dev/null || echo 0)
fi

# Deny the commit — Claude must run /document-commit first
REASON="No docs/versions/ file is staged."
if [ "$UNDOCUMENTED_COUNT" -gt 0 ]; then
  REASON="$REASON There are $UNDOCUMENTED_COUNT undocumented commit(s) since the last documented commit ($LAST_DOC_HASH)."
fi
REASON="$REASON Run /document-commit (auto-detect mode, no arguments) to generate the implementation doc. Then stage it with 'git add docs/versions/' and retry the commit. Do NOT use the Skill tool — read the skill file directly and execute the steps. If the user explicitly asked to skip documentation, tell them this hook requires it and ask how they'd like to proceed."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
