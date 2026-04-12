Summarize commits into implementation documentation, covering all undocumented work.

## Input

The argument is optional. It can be:
- A commit hash or short hash (e.g. `abc123`) — document that single commit
- A range (e.g. `abc123..def456`) — document that range
- **Omitted (default)** — automatically find and document all undocumented commits

## Step 0: Find undocumented commits

If no argument is provided, determine which commits need documentation:

1. List files in `docs/versions/`. Extract the commit hash from the latest file's name (e.g. `1_68cbf20.md` → `68cbf20`).
2. All commits after that hash up to and including HEAD are "undocumented".
3. If no implemented docs exist, all commits on the branch are undocumented.
4. Use the range `{last_documented_hash}..HEAD` as the input for the remaining steps.

If only one commit is undocumented, treat it as a single-commit doc. If multiple, this doc covers the full range.

## Step 1: Determine the output file

List files in `docs/versions/` and find the highest `{N}_*.md` prefix. The new file is `{N+1}_{short_hash}.md`, where `short_hash` is the final commit in the range (i.e. HEAD for the auto-detect case).

## Step 2: Gather commit metadata

For each commit in the range, collect:
- Full commit message
- Author, co-author(s), date
- Diff stats (`git diff --stat` for the full range)
- The full diff (`git diff {first_parent}..{last}` for the range, or `git show` for a single commit)

**Important:** When multiple commits are covered, some changes may have been introduced and then modified or reverted by later commits. Focus on the **net diff** — what actually changed between the state at the last documented commit and HEAD. Don't document intermediate states that no longer exist.

## Step 3: Read architecture and design docs

Read these for context on intended design:
- `docs/designs/architecture.md`
- The most recent (largest `vN.N.md`) design doc in `docs/designs/` — list the directory, sort by major then minor version number, and read the highest one
- The most recent file in `docs/versions/` (for "before" state)

## Step 4: Write the documentation file

Write to `docs/versions/{N+1}_{short_hash}.md` following this structure:

```
# {Summary title describing the net changes}

**Commits:** `{hash1}`, `{hash2}`, ... (all commits covered by this doc)
**Author:** {name(s)}
**Co-Author:** {name(s) if any}
**Date range:** {earliest date} — {latest date} (or single date if one commit)
**Diff (net):** {N} files changed, +{additions} -{deletions} lines

---

## Architecture Changes

### Before
- {state before these commits, based on previous implemented doc}

### After
- {what changed architecturally — new patterns, new modules, structural shifts}
- {only describe what exists in the final state, not intermediate steps}

### New Permissions / Dependencies (if any)
- {manifest changes, new packages, new API endpoints, etc.}

---

## Features Added

### 1. {Feature name} (`{file}`)
- {bullet points describing what was built}

### 2. ...

---

## Schema Changes (if any)

| Table | Primary Key | Purpose |
|-------|------------|---------|

---

## File Summary

| Path | Lines | Purpose |
|------|-------|---------|

---

## Critical Architectural Deviations from Design

Only include this section if the implementation deviates from the latest design doc or `docs/designs/architecture.md`.

### 1. {Deviation title}

**Design:** {what the design doc specifies}
**Implemented:** {what was actually built}
**Impact:** {why this matters}
```

## Step 5: Verify against current code

**This is critical when covering multiple commits.** Some commits may have added code that later commits removed or rewrote. Before finalizing:

1. For every feature or file mentioned in the doc, verify it still exists in the working tree at HEAD.
2. Do not document features, files, or patterns that were introduced and then removed within the covered range.
3. The doc should describe **what the codebase looks like now**, not a changelog of intermediate steps.

## Step 6: Compare against design

Cross-reference what was built against the latest design doc and `architecture.md`. If the implementation matches the design, say so briefly and omit the deviations section.

$ARGUMENTS
