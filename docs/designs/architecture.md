# claude-shared Architecture

## Overview

claude-shared is a reusable collection of Claude Code skills, hooks, and rules that enforces a documentation-first development workflow. It is consumed by other projects via git submodules.

## Components

### Skills

Skills are invocable commands (e.g. `/document-commit`) defined as `SKILL.md` files under `skills/`. They provide structured prompts that Claude follows step-by-step.

### Hooks

Hooks are bash scripts that fire on Claude Code tool events:

- **PreToolUse hooks** intercept tool calls before execution. They can deny the action (e.g. blocking a commit) or run silently.
- **PostToolUse hooks** run after a tool completes. They inject `additionalContext` to guide Claude's next action.

Hooks resolve the git repo root dynamically via `git rev-parse --show-toplevel` so they work regardless of which directory Claude Code was launched from.

### Rules

Rules are markdown files loaded into Claude's context. They can be scoped to specific file paths via frontmatter `paths:` patterns.

### Auto-Update

The `auto-update.sh` hook runs at user-level (`~/.claude/settings.json`) on every session. It:

1. Compares local claude-shared HEAD vs remote (gated by 30-min timestamp)
2. Pulls if behind
3. Updates submodules in the current project, or scans child directories if at a parent level

## Consumption Model

```
claude-shared (this repo)
    │
    ├── git submodule at .claude/shared/ in each consumer project
    │
    └── relative symlinks from .claude/{hooks,skills,rules} → .claude/shared/...
```

Consumer projects commit both the submodule reference (`.gitmodules`) and the symlinks. Collaborators get everything with `git clone --recurse-submodules`.

## Directory Layout

```
claude-shared/
├── docs/
│   ├── designs/          # Design docs (this file, vN.N.md)
│   ├── versions/         # Implementation docs per commit
│   └── plans/            # Approved plans by date
├── hooks/
│   ├── auto-update.sh    # User-level: version check + pull + submodule sync
│   ├── require-commit-doc.sh  # Project-level: blocks commits without docs
│   └── update-design-doc.sh   # Project-level: syncs design docs after plan approval
├── rules/
│   └── doc-workflow.md   # Contextual rules for docs/ editing
├── skills/
│   └── document-commit/
│       └── SKILL.md      # /document-commit skill
├── setup.sh              # Interactive installer (copy/symlink/submodule)
├── update.sh             # Manual pull
└── README.md
```

## Settings Hierarchy

| Level | File | What it configures |
|-------|------|--------------------|
| User | `~/.claude/settings.json` | `auto-update.sh` (fires everywhere) |
| Parent | `~/src/.claude/settings.json` | `require-commit-doc.sh` + `update-design-doc.sh` (catches cross-project work) |
| Project | `<project>/.claude/settings.json` | Same hooks via submodule symlinks |

All three levels merge at runtime. Project-level hooks take precedence but user/parent hooks ensure coverage when working from non-project directories.
