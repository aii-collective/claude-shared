Generate or update the project's architecture and design documentation by analyzing the codebase.

## Context

This skill runs after `setup.sh` has created the `docs/` directory structure, or anytime the docs need updating. It reads the project's code, README, and any existing documentation to produce meaningful architecture and design docs — not placeholder templates.

## Step 1: Assess what exists

Read the following to understand the project:

1. `README.md` (or `README`) at the project root
2. `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, or equivalent — for project metadata and dependencies
3. `docs/designs/architecture.md` — may be empty/template or contain real content
4. The latest `docs/designs/vN.N.md` — may be empty/template or contain real content
5. Any other files in `docs/` (e.g. existing specs, ADRs, guides)
6. The top-level directory structure (`ls -la` and key subdirectories)
7. `git log --oneline -20` — recent history for context on what's being worked on

## Step 2: Determine what's needed

Check each doc file for real content vs template placeholders (HTML comments like `<!-- ... -->` or empty sections).

- If `architecture.md` is missing or is a template → generate it
- If no `vN.N.md` exists or the latest is a template → generate it
- If both have real content → report what exists and ask if the user wants updates

## Step 3: Gather missing context

If the codebase doesn't have enough information to write meaningful docs (e.g. it's a new project with minimal code), start a conversation:

- Ask about the project's purpose and goals
- Ask about the intended architecture and key design decisions
- Ask about the target users and deployment model
- Ask about what's in scope for the current version

Use the answers to inform the docs. Do NOT write vague placeholder content — if you don't have enough information, ask rather than guess.

## Step 4: Write architecture.md

Generate `docs/designs/architecture.md` covering:

- **Overview** — what the project does, in 2-3 sentences
- **Components** — major modules/services and their responsibilities
- **Data flow** — how data moves through the system (if applicable)
- **Directory layout** — what lives where, annotated
- **Dependencies** — key external dependencies and why they're used
- **Conventions** — patterns used in the codebase (naming, error handling, etc.)

Base this on what you actually see in the code. Reference specific files and directories. Do not write aspirational documentation about things that don't exist yet.

## Step 5: Write or update design doc

Generate `docs/designs/v0.1.md` (or the next version if others exist) covering:

- **Goals** — what this version aims to achieve
- **Design decisions** — key choices and their rationale, based on what's implemented
- **Scope** — what's included and what's deferred

If design docs already exist with real content, create the next version number and focus on what's changed or been decided since the last version.

## Step 6: Verify accuracy

For every claim in the docs:
1. Verify the referenced files/directories/functions actually exist
2. Do not describe features or patterns that aren't in the codebase
3. The docs should describe **what is**, not **what should be**

$ARGUMENTS
