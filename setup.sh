#!/bin/bash
# setup.sh — Install claude-shared skills, hooks, and rules into a target project.
#
# Usage:
#   /path/to/claude-shared/setup.sh [--mode copy|symlink|submodule] [target-project-dir]
#
# If target-project-dir is omitted, uses the current directory.
# If --mode is omitted, an interactive arrow-key menu is shown.

set -euo pipefail

# ==============================================================================
# Constants
# ==============================================================================

PROJECT_HOOKS=("require-commit-doc.sh" "update-design-doc.sh")
SKILLS=("document-commit")
RULES=("doc-workflow.md")
VERSION_FILE=".claude/.claude-shared-version"

# ==============================================================================
# TUI: Arrow-key menu
# ==============================================================================

# Renders a menu with arrow-key navigation and Enter to select.
# Usage: menu_select RESULT_VAR "prompt" "label1|description1" "label2|description2" ...
# The default (first call) is the last item if it contains "(recommended)".
menu_select() {
  local -n _result=$1
  local prompt="$2"
  shift 2
  local options=("$@")
  local count=${#options[@]}
  local selected=0

  # Find recommended option (default selection)
  for i in "${!options[@]}"; do
    if echo "${options[$i]}" | grep -qi "recommended"; then
      selected=$i
      break
    fi
  done

  # Hide cursor
  tput civis 2>/dev/null || true

  # Cleanup on exit
  trap 'tput cnorm 2>/dev/null || true' RETURN

  while true; do
    # Clear menu area and redraw
    echo -e "\033[1m${prompt}\033[0m" >&2
    echo "" >&2

    for i in "${!options[@]}"; do
      local label="${options[$i]%%|*}"
      local desc="${options[$i]#*|}"

      if [ "$i" -eq "$selected" ]; then
        echo -e "  \033[7m > ${label} \033[0m" >&2
        echo -e "    \033[2m${desc}\033[0m" >&2
      else
        echo -e "    ${label}" >&2
        echo -e "    \033[2m${desc}\033[0m" >&2
      fi
    done

    echo "" >&2
    echo -e "  \033[2m↑↓ to move, Enter to select\033[0m" >&2

    # Read a single keypress
    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')  # Escape sequence (arrow keys)
        read -rsn2 rest
        case "$rest" in
          '[A') selected=$(( (selected - 1 + count) % count )) ;;  # Up
          '[B') selected=$(( (selected + 1) % count )) ;;          # Down
        esac
        ;;
      '')  # Enter
        break
        ;;
    esac

    # Move cursor up to redraw menu (prompt + blank + options*2 + blank + hint)
    local lines=$(( 2 + count * 2 + 2 ))
    echo -en "\033[${lines}A\033[J" >&2
  done

  _result=$selected
}

# ==============================================================================
# Helpers
# ==============================================================================

ensure_jq() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "  macOS: brew install jq"
    echo "  Linux: apt install jq / yum install jq"
    exit 1
  fi
}

relpath() {
  # Compute relative path from $1 to $2
  python3 -c "import os.path; print(os.path.relpath('$2', '$1'))"
}

write_version_file() {
  local target_dir="$1"
  local mode="$2"
  local shared_dir="$3"

  local commit
  commit=$(git -C "$shared_dir" rev-parse HEAD 2>/dev/null || echo "unknown")
  local commit_short
  commit_short=$(git -C "$shared_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  local remote
  remote=$(git -C "$shared_dir" remote get-url origin 2>/dev/null || echo "(no remote)")
  local date
  date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  cat > "$target_dir/$VERSION_FILE" <<EOF
# Installed by claude-shared setup.sh
mode=${mode}
commit=${commit}
commit_short=${commit_short}
date=${date}
source=${remote}
EOF
  echo "  [write] .claude-shared-version (${mode}, ${commit_short})"
}

detect_existing() {
  local target_dir="$1"
  if [ -f "$target_dir/$VERSION_FILE" ]; then
    # shellcheck disable=SC1090
    source <(grep -E '^(mode|commit|commit_short|date)=' "$target_dir/$VERSION_FILE")
    echo "$mode"
  fi
}

# ==============================================================================
# Installation modes
# ==============================================================================

install_copy() {
  local shared_dir="$1"
  local target_dir="$2"

  mkdir -p "$target_dir/.claude/"{skills/document-commit,hooks,rules}

  for hook in "${PROJECT_HOOKS[@]}"; do
    # Remove existing symlink if switching modes
    [ -L "$target_dir/.claude/hooks/$hook" ] && rm "$target_dir/.claude/hooks/$hook"
    cp "$shared_dir/hooks/$hook" "$target_dir/.claude/hooks/$hook"
    chmod +x "$target_dir/.claude/hooks/$hook"
    echo "  [copy] hooks/$hook"
  done

  for skill in "${SKILLS[@]}"; do
    [ -L "$target_dir/.claude/skills/$skill" ] && rm "$target_dir/.claude/skills/$skill"
    cp -R "$shared_dir/skills/$skill/" "$target_dir/.claude/skills/$skill/"
    echo "  [copy] skills/$skill/"
  done

  for rule in "${RULES[@]}"; do
    [ -L "$target_dir/.claude/rules/$rule" ] && rm "$target_dir/.claude/rules/$rule"
    cp "$shared_dir/rules/$rule" "$target_dir/.claude/rules/$rule"
    echo "  [copy] rules/$rule"
  done

  write_version_file "$target_dir" "copy" "$shared_dir"
}

install_symlink() {
  local shared_dir="$1"
  local target_dir="$2"

  mkdir -p "$target_dir/.claude/"{skills,hooks,rules}

  # Compute relative path from .claude/ subdirs to shared_dir
  local rel_from_hooks
  rel_from_hooks=$(relpath "$target_dir/.claude/hooks" "$shared_dir/hooks")
  local rel_from_skills
  rel_from_skills=$(relpath "$target_dir/.claude/skills" "$shared_dir/skills")
  local rel_from_rules
  rel_from_rules=$(relpath "$target_dir/.claude/rules" "$shared_dir/rules")

  for hook in "${PROJECT_HOOKS[@]}"; do
    ln -sf "$rel_from_hooks/$hook" "$target_dir/.claude/hooks/$hook"
    echo "  [link] hooks/$hook -> $rel_from_hooks/$hook"
  done

  for skill in "${SKILLS[@]}"; do
    # Remove if it's a directory (copy mode artifact)
    [ -d "$target_dir/.claude/skills/$skill" ] && [ ! -L "$target_dir/.claude/skills/$skill" ] && rm -rf "$target_dir/.claude/skills/$skill"
    ln -sf "$rel_from_skills/$skill" "$target_dir/.claude/skills/$skill"
    echo "  [link] skills/$skill -> $rel_from_skills/$skill"
  done

  for rule in "${RULES[@]}"; do
    ln -sf "$rel_from_rules/$rule" "$target_dir/.claude/rules/$rule"
    echo "  [link] rules/$rule -> $rel_from_rules/$rule"
  done

  # Auto-update .gitignore
  local gitignore="$target_dir/.gitignore"
  local marker="# claude-shared symlinks (mode: symlink)"
  if ! grep -qF "$marker" "$gitignore" 2>/dev/null; then
    {
      echo ""
      echo "$marker"
      for hook in "${PROJECT_HOOKS[@]}"; do
        echo ".claude/hooks/$hook"
      done
      for skill in "${SKILLS[@]}"; do
        echo ".claude/skills/$skill"
      done
      for rule in "${RULES[@]}"; do
        echo ".claude/rules/$rule"
      done
    } >> "$gitignore"
    echo "  [update] .gitignore — added symlink entries"
  else
    echo "  [skip] .gitignore already has claude-shared entries"
  fi

  write_version_file "$target_dir" "symlink" "$shared_dir"
}

install_submodule() {
  local shared_dir="$1"
  local target_dir="$2"

  local remote
  remote=$(git -C "$shared_dir" remote get-url origin 2>/dev/null || true)

  if [ -z "$remote" ]; then
    echo ""
    echo "  Error: claude-shared has no remote configured."
    echo "  Submodule mode requires a remote URL. Push claude-shared first:"
    echo "    cd $shared_dir"
    echo "    git remote add origin <url>"
    echo "    git push -u origin main"
    exit 1
  fi

  mkdir -p "$target_dir/.claude/"{skills,hooks,rules}

  # Add or update submodule
  local submodule_path=".claude/shared"
  if git -C "$target_dir" config --file .gitmodules "submodule.${submodule_path}.url" &>/dev/null; then
    echo "  [ok] Submodule already registered at $submodule_path"
    git -C "$target_dir" submodule update --init --recursive "$submodule_path"
  else
    echo "  [add] git submodule at $submodule_path"
    git -C "$target_dir" submodule add "$remote" "$submodule_path"
  fi

  # Create relative symlinks from .claude/{hooks,skills,rules} into .claude/shared/
  for hook in "${PROJECT_HOOKS[@]}"; do
    ln -sf "../shared/hooks/$hook" "$target_dir/.claude/hooks/$hook"
    echo "  [link] hooks/$hook -> ../shared/hooks/$hook"
  done

  for skill in "${SKILLS[@]}"; do
    [ -d "$target_dir/.claude/skills/$skill" ] && [ ! -L "$target_dir/.claude/skills/$skill" ] && rm -rf "$target_dir/.claude/skills/$skill"
    ln -sf "../shared/skills/$skill" "$target_dir/.claude/skills/$skill"
    echo "  [link] skills/$skill -> ../shared/skills/$skill"
  done

  for rule in "${RULES[@]}"; do
    ln -sf "../shared/rules/$rule" "$target_dir/.claude/rules/$rule"
    echo "  [link] rules/$rule -> ../shared/rules/$rule"
  done

  write_version_file "$target_dir" "submodule" "$shared_dir"
}

# ==============================================================================
# Settings configuration
# ==============================================================================

configure_project_settings() {
  local target_dir="$1"
  local settings_file="$target_dir/.claude/settings.json"

  local hook_config='{
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

  if [ ! -f "$settings_file" ]; then
    echo "$hook_config" > "$settings_file"
    echo "  [create] settings.json with hook configuration"
  elif jq -e '.hooks.PreToolUse' "$settings_file" >/dev/null 2>&1; then
    echo "  [skip] settings.json already has hooks configured"
  else
    local merged
    merged=$(jq -s '.[0] * .[1]' "$settings_file" <(echo "$hook_config"))
    echo "$merged" > "$settings_file"
    echo "  [merge] Added hook configuration to settings.json"
  fi
}

configure_user_settings() {
  local user_settings="$HOME/.claude/settings.json"

  if [ -f "$user_settings" ] && grep -q "auto-update.sh" "$user_settings" 2>/dev/null; then
    echo "  [skip] Auto-update hook already in ~/.claude/settings.json"
    return
  fi

  local auto_hook_config='{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/src/claude-shared/hooks/auto-update.sh"
          }
        ]
      }
    ]
  }
}'

  mkdir -p "$HOME/.claude"

  if [ ! -f "$user_settings" ]; then
    echo "$auto_hook_config" > "$user_settings"
    echo "  [create] ~/.claude/settings.json with auto-update hook"
  else
    local merged
    merged=$(jq -s 'if .[0].hooks.PreToolUse then .[0] * {hooks: {PreToolUse: (.[0].hooks.PreToolUse + .[1].hooks.PreToolUse)}} else .[0] * .[1] end' "$user_settings" <(echo "$auto_hook_config"))
    echo "$merged" > "$user_settings"
    echo "  [merge] Added auto-update hook to ~/.claude/settings.json"
  fi
}

# ==============================================================================
# Cleanup when switching modes
# ==============================================================================

cleanup_previous() {
  local target_dir="$1"
  local prev_mode="$2"

  echo ""
  echo "  Cleaning up previous installation (${prev_mode})..."

  case "$prev_mode" in
    copy)
      for hook in "${PROJECT_HOOKS[@]}"; do
        [ -f "$target_dir/.claude/hooks/$hook" ] && [ ! -L "$target_dir/.claude/hooks/$hook" ] && rm "$target_dir/.claude/hooks/$hook"
      done
      for skill in "${SKILLS[@]}"; do
        [ -d "$target_dir/.claude/skills/$skill" ] && [ ! -L "$target_dir/.claude/skills/$skill" ] && rm -rf "$target_dir/.claude/skills/$skill"
      done
      for rule in "${RULES[@]}"; do
        [ -f "$target_dir/.claude/rules/$rule" ] && [ ! -L "$target_dir/.claude/rules/$rule" ] && rm "$target_dir/.claude/rules/$rule"
      done
      ;;
    symlink)
      for hook in "${PROJECT_HOOKS[@]}"; do
        [ -L "$target_dir/.claude/hooks/$hook" ] && rm "$target_dir/.claude/hooks/$hook"
      done
      for skill in "${SKILLS[@]}"; do
        [ -L "$target_dir/.claude/skills/$skill" ] && rm "$target_dir/.claude/skills/$skill"
      done
      for rule in "${RULES[@]}"; do
        [ -L "$target_dir/.claude/rules/$rule" ] && rm "$target_dir/.claude/rules/$rule"
      done
      # Remove gitignore entries
      if [ -f "$target_dir/.gitignore" ]; then
        sed -i '' '/# claude-shared symlinks/d; /\.claude\/hooks\/require-commit-doc\.sh/d; /\.claude\/hooks\/update-design-doc\.sh/d; /\.claude\/skills\/document-commit/d; /\.claude\/rules\/doc-workflow\.md/d' "$target_dir/.gitignore" 2>/dev/null || true
      fi
      ;;
    submodule)
      if git -C "$target_dir" config --file .gitmodules "submodule..claude/shared.url" &>/dev/null; then
        git -C "$target_dir" submodule deinit -f .claude/shared 2>/dev/null || true
        git -C "$target_dir" rm -f .claude/shared 2>/dev/null || true
        rm -rf "$target_dir/.git/modules/.claude/shared" 2>/dev/null || true
      fi
      for hook in "${PROJECT_HOOKS[@]}"; do
        [ -L "$target_dir/.claude/hooks/$hook" ] && rm "$target_dir/.claude/hooks/$hook"
      done
      for skill in "${SKILLS[@]}"; do
        [ -L "$target_dir/.claude/skills/$skill" ] && rm "$target_dir/.claude/skills/$skill"
      done
      for rule in "${RULES[@]}"; do
        [ -L "$target_dir/.claude/rules/$rule" ] && rm "$target_dir/.claude/rules/$rule"
      done
      ;;
  esac

  echo "  Cleanup done."
}

# ==============================================================================
# Main
# ==============================================================================

main() {
  ensure_jq

  SHARED_DIR="$(cd "$(dirname "$0")" && pwd)"

  # Parse arguments
  local cli_mode=""
  local target_arg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        cli_mode="$2"
        if [[ ! "$cli_mode" =~ ^(copy|symlink|submodule)$ ]]; then
          echo "Error: --mode must be copy, symlink, or submodule (got: $cli_mode)"
          exit 1
        fi
        shift 2
        ;;
      *)
        target_arg="$1"
        shift
        ;;
    esac
  done

  TARGET_DIR="${target_arg:-.}"
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

  # Validate target is a git repo
  if ! git -C "$TARGET_DIR" rev-parse --git-dir &>/dev/null; then
    echo "Error: $TARGET_DIR is not a git repository."
    echo "All installation modes require git. Run 'git init' first."
    exit 1
  fi

  local shared_commit_short
  shared_commit_short=$(git -C "$SHARED_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

  echo ""
  echo "  claude-shared setup"
  echo "  ═══════════════════"
  echo "  Source:  $SHARED_DIR (${shared_commit_short})"
  echo "  Target:  $TARGET_DIR"
  echo ""

  # Detect existing installation
  local prev_mode=""
  prev_mode=$(detect_existing "$TARGET_DIR")

  if [ -n "$prev_mode" ]; then
    # shellcheck disable=SC1090
    source <(grep -E '^(commit_short|date)=' "$TARGET_DIR/$VERSION_FILE")
    echo "  Existing installation detected:"
    echo "    Mode:      ${prev_mode}"
    echo "    Installed: ${commit_short:-unknown} (${date:-unknown})"
    echo "    Available: ${shared_commit_short}"
    echo ""
  fi

  # Mode selection
  local mode
  if [ -n "$cli_mode" ]; then
    mode="$cli_mode"
  else
    local choice
    menu_select choice \
      "  How would you like to install claude-shared?" \
      "Copy|Files copied into .claude/, version tracked. Fully portable, no external deps." \
      "Symlink|Relative symlinks to sibling clone. Auto-configures .gitignore." \
      "Submodule (recommended)|Git submodule at .claude/shared/. Portable + updatable."

    case $choice in
      0) mode="copy" ;;
      1) mode="symlink" ;;
      2) mode="submodule" ;;
    esac
  fi

  echo ""
  echo "  Installing with mode: ${mode}"
  echo ""

  # Cleanup previous if switching modes
  if [ -n "$prev_mode" ] && [ "$prev_mode" != "$mode" ]; then
    cleanup_previous "$TARGET_DIR" "$prev_mode"
  fi

  # Install
  case "$mode" in
    copy)     install_copy "$SHARED_DIR" "$TARGET_DIR" ;;
    symlink)  install_symlink "$SHARED_DIR" "$TARGET_DIR" ;;
    submodule) install_submodule "$SHARED_DIR" "$TARGET_DIR" ;;
  esac

  echo ""

  # Configure settings
  configure_project_settings "$TARGET_DIR"
  configure_user_settings

  # Docs check
  echo ""
  if [ ! -d "$TARGET_DIR/docs/versions" ]; then
    echo "  [note] docs/versions/ does not exist yet"
    echo "         Create it when ready: mkdir -p docs/versions docs/designs docs/plans"
  else
    echo "  [ok] docs/versions/ exists"
  fi

  # Summary
  echo ""
  echo "  ✓ claude-shared installed (mode: ${mode})"
  echo ""

  case "$mode" in
    copy)
      echo "  Next steps:"
      echo "    1. Create docs dirs if needed:  mkdir -p docs/versions docs/designs docs/plans"
      echo "    2. Commit .claude/ to your repo"
      echo "    3. Re-run setup.sh to update to a newer version"
      ;;
    symlink)
      echo "  Next steps:"
      echo "    1. Create docs dirs if needed:  mkdir -p docs/versions docs/designs docs/plans"
      echo "    2. Commit .claude/settings.json and .claude/.claude-shared-version"
      echo "    3. Collaborators: clone claude-shared as a sibling, then run setup.sh"
      ;;
    submodule)
      echo "  Next steps:"
      echo "    1. Create docs dirs if needed:  mkdir -p docs/versions docs/designs docs/plans"
      echo "    2. Commit:  git add .gitmodules .claude/ && git commit"
      echo "    3. Collaborators:  git clone --recurse-submodules <url>"
      echo "    4. Update:  git submodule update --remote .claude/shared"
      ;;
  esac

  echo ""
}

main "$@"
