#!/bin/bash
# update.sh — Pull the latest claude-shared and show what changed.
#
# Usage:
#   ~/src/claude-shared/update.sh
#
# Since consumer projects use symlinks, pulling here updates all linked projects.

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SHARED_DIR"

echo "claude-shared update"
echo "  Location: $SHARED_DIR"
echo ""

# Check for uncommitted local changes
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo "  [warn] You have local changes. Stashing before pull..."
  git stash
  STASHED=true
else
  STASHED=false
fi

BEFORE=$(git rev-parse HEAD)

# Pull latest
if git remote | grep -q origin; then
  git pull --ff-only origin main 2>&1 | sed 's/^/  /'
else
  echo "  [skip] No remote configured — nothing to pull"
  echo "         Add one with: git remote add origin <url>"
  exit 0
fi

AFTER=$(git rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  echo ""
  echo "  Already up to date."
else
  echo ""
  echo "  Updated: $BEFORE -> $AFTER"
  echo ""
  echo "  Changes:"
  git log --oneline "$BEFORE..$AFTER" | sed 's/^/    /'
fi

if [ "$STASHED" = true ]; then
  echo ""
  echo "  [info] Restoring stashed local changes..."
  git stash pop
fi

echo ""
echo "All linked projects are now using the latest version (symlinks resolve live)."
