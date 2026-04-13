#!/bin/bash
# PostToolUse hook: after ExitPlanMode, instruct Claude to update the latest design doc.
# The hook injects additionalContext so Claude (not this script) does the actual update.
#
# Part of claude-shared — https://github.com/aii-collective/claude-shared

# Resolve the project root — try git repo root first, fall back to CLAUDE_PROJECT_DIR
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
fi

if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# Find the latest vN.N.md design doc
DESIGNS_DIR="$PROJECT_ROOT/docs/designs"
LATEST_DESIGN=$(ls -1 "$DESIGNS_DIR"/v*.md 2>/dev/null | sort -t'v' -k2 -V | tail -1)

if [ -z "$LATEST_DESIGN" ]; then
  # No design docs exist — nothing to update
  exit 0
fi

LATEST_NAME=$(basename "$LATEST_DESIGN")

PLANS_DIR="$PROJECT_ROOT/docs/plans"
DATE_FOLDER=$(date +%Y-%m-%d)
mkdir -p "$PLANS_DIR/$DATE_FOLDER"

jq -n --arg doc "$LATEST_NAME" --arg dateFolder "$DATE_FOLDER" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("The plan was just approved. Do TWO things:\n\n1. SAVE VERBATIM PLAN: Copy the exact plan text from the conversation above — do NOT summarize, rewrite, or regenerate it. Choose a short kebab-case topic name that describes the plan (e.g. \"skill-graph-refactor\", \"auth-flow\", \"mcp-hosting\"). Write it as-is to docs/plans/" + $dateFolder + "/{topic}.md. This is a permanent record of what was planned.\n\n2. UPDATE DESIGN DOC: Update the latest design doc at docs/designs/" + $doc + " to incorporate any decisions, changes, or new details from the approved plan. Read the current design doc, merge in the plan content (preserving existing structure and sections), and write the updated file. Only update sections that are affected by the plan — do not rewrite unchanged content.\n\nIf the plan was trivial or not related to design, skip step 2 but still do step 1.")
  }
}'
