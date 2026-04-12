---
paths:
  - "docs/**"
---

# Documentation-First Workflow

This project uses a documentation-first workflow enforced by claude-shared hooks.

## How it works

1. **Every commit must be documented.** A pre-commit hook blocks `git commit` unless a file in `docs/versions/` is staged.
2. **Use `/document-commit`** to generate implementation docs before committing. It auto-detects undocumented commits and writes structured docs to `docs/versions/`.
3. **Plans are preserved.** When a plan is approved (ExitPlanMode), the plan text is saved verbatim to `docs/plans/{date}/{topic}.md` and the latest design doc is updated.

## Directory structure

- `docs/versions/` — Implementation docs, one per commit or commit range (e.g. `1_68cbf20.md`)
- `docs/designs/` — Design docs versioned as `vN.N.md`, plus `architecture.md`
- `docs/plans/` — Approved plans organized by date

## When writing implementation docs

- Focus on the **net diff** — what the codebase looks like now, not intermediate states
- Verify every documented feature still exists in the working tree
- Cross-reference against design docs and note deviations
