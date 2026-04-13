# Initial implementation — documentation-first workflow for Claude Code

**Commits:** `f9fc9e4`, `cae755d`, `263c5ed`, `16136e8`, `0e791a4`, `36b9aef`, `29a75c5`, `f700452`, `7daed5f`
**Author:** Andy Wong
**Co-Author:** Claude Opus 4.6 (1M context)
**Date range:** 2026-04-12 — 2026-04-12
**Diff (net):** 9 files changed, +900 lines

---

## Architecture Changes

### Before
- Tab42 and tiramisu had identical but independent `.claude` configurations
- Hooks, commands, and settings were duplicated — fixes required updating both repos
- No shared infrastructure for Claude Code configuration across projects

### After
- Centralized shared repo (`claude-shared`) with skills, hooks, and rules
- Consumer projects use git submodules at `.claude/shared/` with relative symlinks
- Three-tier settings hierarchy: user-level (auto-update), parent-level (hooks), project-level (hooks via submodule)
- Hooks resolve git repo root dynamically — work from any directory
- Auto-update pulls claude-shared and syncs all project submodules

### New Dependencies
- `jq` required by hooks and setup.sh
- `python3` used by setup.sh for relative path computation (symlink mode)

---

## Features Added

### 1. `/document-commit` skill (`skills/document-commit/SKILL.md`)
- Migrated from legacy `.claude/commands/` to modern `.claude/skills/` format
- Auto-detects undocumented commits via `docs/versions/` file inspection
- Generates structured implementation docs: architecture changes, features, schema, file summary, design deviations
- Verifies documented features still exist in working tree (net diff, not changelog)

### 2. Pre-commit documentation hook (`hooks/require-commit-doc.sh`)
- Blocks `git commit` unless a `docs/versions/` file is staged
- Reports count of undocumented commits with guidance
- Resolves git repo root via `git rev-parse --show-toplevel` — works from parent directories
- Gracefully skips if `docs/versions/` doesn't exist in the project

### 3. Post-plan design doc hook (`hooks/update-design-doc.sh`)
- Fires after plan approval (ExitPlanMode)
- Saves plan verbatim to `docs/plans/{date}/{topic}.md`
- Updates latest `docs/designs/vN.N.md` with plan decisions
- Resolves project root via git, falls back to `$CLAUDE_PROJECT_DIR`

### 4. Auto-update hook (`hooks/auto-update.sh`)
- User-level hook in `~/.claude/settings.json` — fires every session
- Compares local HEAD vs remote, pulls if behind (30-min gate, 5s fetch timeout)
- Updates submodule in current project, or scans all child directories at parent level
- Logs changes to stderr for visibility

### 5. Interactive setup script (`setup.sh`)
- Arrow-key TUI menu for mode selection (Copy / Symlink / Submodule)
- `--mode` flag for non-interactive CI/scripting use
- Version tracking via `.claude/.claude-shared-version`
- Re-run detection with mode switching and cleanup
- Auto-configures project `settings.json` and user-level auto-update hook
- Symlink mode auto-appends `.gitignore` entries

### 6. Manual update script (`update.sh`)
- One-command pull with stash handling and changelog display

### 7. Doc-workflow rule (`rules/doc-workflow.md`)
- Scoped to `docs/**` paths
- Provides Claude with documentation structure context

---

## File Summary

| Path | Lines | Purpose |
|------|-------|---------|
| `skills/document-commit/SKILL.md` | 117 | Skill definition for /document-commit |
| `hooks/require-commit-doc.sh` | 57 | PreToolUse: block commits without docs |
| `hooks/update-design-doc.sh` | 34 | PostToolUse: save plans, update design docs |
| `hooks/auto-update.sh` | 82 | PreToolUse (user-level): version check + submodule sync |
| `rules/doc-workflow.md` | 25 | Contextual rules for docs/ editing |
| `setup.sh` | 380 | Interactive installer with 3 modes |
| `update.sh` | 45 | Manual pull script |
| `README.md` | 282 | Human-facing documentation with architecture diagrams |
| `docs/designs/architecture.md` | — | Architecture overview |
| `docs/designs/v0.1.md` | — | Initial design document |

---

## Critical Architectural Deviations from Design

No deviations — this is the initial implementation that established the design.
