# claude-shared

Shared [Claude Code](https://claude.ai/code) skills, hooks, and rules for a **documentation-first development workflow**.

## What this does

This collection enforces a simple discipline: **every commit is documented**. When you work with Claude Code in any project that adopts this workflow, the following happens automatically:

1. **Before every commit**, a hook checks whether you've documented your changes. If not, it blocks the commit and tells Claude to run `/document-commit` first.
2. **`/document-commit`** is a skill that reads your git history, diffs, and design docs, then writes a structured implementation doc to `docs/versions/`. It covers architecture changes, new features, schema changes, file summaries, and deviations from design.
3. **After approving a plan**, a hook saves the plan verbatim to `docs/plans/` and updates the latest design doc to reflect new decisions.

The result is a living record of *what was built, why, and how it differs from what was designed* — without manual effort.

## Why this exists

- **Knowledge doesn't live only in code.** Commits show *what* changed; implementation docs explain *why* and how it fits the architecture.
- **Design docs stay current.** Plans are captured as they're approved, and design docs are updated automatically — no drift.
- **Code reviews are richer.** Reviewers get structured summaries alongside diffs.
- **Onboarding is faster.** New contributors can read `docs/versions/` chronologically to understand how the project evolved.

## What's included

```
claude-shared/
├── skills/
│   └── document-commit/       # /document-commit skill
│       └── SKILL.md           # Auto-generates implementation docs from commits
├── hooks/
│   ├── require-commit-doc.sh  # Blocks commits without staged docs
│   └── update-design-doc.sh   # Saves plans + updates design docs after plan approval
├── rules/
│   └── doc-workflow.md        # Contextual rules for Claude when editing docs/
├── setup.sh                   # One-command setup for new projects
└── README.md
```

### Skills

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `/document-commit` | Manual or prompted by hook | Reads git history and diffs, cross-references design docs, writes a structured implementation doc to `docs/versions/{N}_{hash}.md` |

### Hooks

| Hook | When it fires | What it does |
|------|---------------|-------------|
| `require-commit-doc.sh` | Before any `git commit` (PreToolUse) | Denies the commit if no `docs/versions/` file is staged. Tells Claude how many commits are undocumented and what to do. Skips enforcement if `docs/versions/` doesn't exist in the project. |
| `update-design-doc.sh` | After plan approval (PostToolUse on ExitPlanMode) | Saves the approved plan to `docs/plans/{date}/{topic}.md` and updates the latest `docs/designs/vN.N.md` with plan decisions. Skips if no design docs exist. |

### Rules

| Rule | Scope | What it does |
|------|-------|-------------|
| `doc-workflow.md` | Files matching `docs/**` | Gives Claude context about the documentation structure and workflow conventions |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    claude-shared repo                     │
│                                                          │
│  skills/document-commit/   hooks/        rules/          │
│       SKILL.md         require-commit-doc.sh             │
│                        update-design-doc.sh              │
│                                          doc-workflow.md │
└──────────┬──────────────────┬───────────────┬────────────┘
           │ symlink          │ symlink       │ symlink
           ▼                  ▼               ▼
┌──────────────────────────────────────────────────────────┐
│                  Your Project (.claude/)                   │
│                                                           │
│  skills/document-commit/ ──→ shared skill                 │
│  hooks/require-commit-doc.sh ──→ shared hook              │
│  hooks/update-design-doc.sh ──→ shared hook               │
│  rules/doc-workflow.md ──→ shared rule                    │
│  settings.json  (project-specific, references hooks)      │
└──────────────────────────────────────────────────────────┘

                    Hook Lifecycle
                    ═════════════

  Developer works with Claude Code
           │
           ▼
  Claude runs `git commit`
           │
           ▼
  ┌─────────────────────────┐
  │  PreToolUse hook fires  │
  │  require-commit-doc.sh  │
  └───────────┬─────────────┘
              │
     ┌────────┴────────┐
     │                  │
  docs/versions/     No docs
  file staged?       staged
     │                  │
     ▼                  ▼
  ALLOW             DENY commit
  commit            → Claude runs /document-commit
                    → Generates docs/versions/{N}_{hash}.md
                    → Stages it
                    → Retries commit ✓


  Developer approves a plan (ExitPlanMode)
           │
           ▼
  ┌──────────────────────────┐
  │  PostToolUse hook fires  │
  │  update-design-doc.sh    │
  └───────────┬──────────────┘
              │
              ▼
  1. Save plan → docs/plans/{date}/{topic}.md
  2. Update   → docs/designs/vN.N.md
```

## Setup

### Prerequisites

Your project needs a `docs/` directory structure:

```
your-project/
├── docs/
│   ├── versions/        # Implementation docs go here (created by /document-commit)
│   ├── designs/         # Design docs: architecture.md, v0.1.md, v0.2.md, ...
│   └── plans/           # Approved plans (created by hook)
└── .claude/             # Created by setup.sh
```

### Installation

1. **Clone this repo** alongside your projects:

   ```bash
   cd ~/src  # or wherever your projects live
   git clone https://github.com/aii-collective/claude-shared.git
   ```

2. **Run setup** from your target project:

   ```bash
   cd ~/src/my-project
   ~/src/claude-shared/setup.sh
   ```

   Or specify a path:

   ```bash
   ~/src/claude-shared/setup.sh ~/src/my-project
   ```

3. **Create the docs structure** (if it doesn't exist):

   ```bash
   mkdir -p docs/versions docs/designs docs/plans
   ```

4. **Create initial design docs**:
   - `docs/designs/architecture.md` — High-level architecture overview
   - `docs/designs/v0.1.md` — First design version

5. **Start Claude Code** and the workflow is active.

### What setup.sh does

- Creates `.claude/skills/`, `.claude/hooks/`, `.claude/rules/` directories
- Symlinks skills, hooks, and rules from this repo into your project
- Creates or merges hook configuration into `.claude/settings.json`
- Reports what was linked and any manual steps needed

It's safe to run multiple times — it skips existing symlinks and warns about conflicts.

## Contributing

### Adding a new skill

1. Create a directory under `skills/` with a `SKILL.md` file
2. Update `setup.sh` to link the new skill
3. Add a description to this README

### Adding a new hook

1. Add the script to `hooks/`
2. Make it executable (`chmod +x`)
3. Update `setup.sh` to link it and add the settings.json configuration
4. Document the trigger condition and behavior in this README

### Adding a new rule

1. Add a `.md` file to `rules/`
2. Use frontmatter `paths:` to scope when it loads (optional)
3. Update `setup.sh` to link it

### Testing changes

After modifying a shared file, changes take effect immediately in all linked projects (symlinks point to the source). Test in a project:

```bash
# Verify the skill loads
# In Claude Code: /document-commit

# Verify the commit hook fires
git add some-file.txt
# In Claude Code: ask Claude to commit — it should be blocked

# Verify the plan hook fires
# In Claude Code: approve a plan — it should save to docs/plans/
```

## License

MIT
