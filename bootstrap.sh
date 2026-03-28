#!/usr/bin/env bash
#
# Bootstrap a Claude Code project with structured docs, tasks, and workflow.
#
# Usage:
#   cd your-repo
#   bash /path/to/bootstrap.sh "Project Name"
#
# What it creates:
#   CLAUDE.md                          — Root instructions for Claude
#   docs/human/specification.md        — Human-owned project spec (template)
#   docs/human/workflow.md             — Human-owned workflow rules
#   docs/agent/                        — Agent-owned design docs (empty)
#   tasks/index.md                     — Task dashboard
#   tasks/goals/                       — Active goal folders
#   tasks/backlog/                     — Backlog items
#   tasks/archive/                     — Completed goals
#   .claude/commands/new-goal.md       — /new-goal slash command
#   .claude/commands/work-task.md      — /work-task slash command

set -euo pipefail

PROJECT_NAME="${1:-My Project}"

if [ ! -d .git ]; then
  echo "Warning: Not a git repository. Initialising one."
  git init
fi

# ─── Directories ────────────────────────────────────────────────────────────

mkdir -p docs/human docs/agent tasks/goals tasks/backlog tasks/archive .claude/commands

touch docs/agent/.gitkeep tasks/goals/.gitkeep tasks/backlog/.gitkeep tasks/archive/.gitkeep

# ─── CLAUDE.md ──────────────────────────────────────────────────────────────

cat > CLAUDE.md << 'CLAUDE_EOF'
# CLAUDE.md

## Read Order

Before any task, read in this order:
1. `docs/human/specification.md`
2. `docs/human/workflow.md`
3. Relevant design docs in `docs/agent/`

## Ownership

- `docs/human/` — Human-owned. Never edit.
- `docs/agent/` — Agent-owned. Keep exhaustive and current.
- `tasks/` — Agent-managed. Follow workflow rules.

## Workflow

All functional code changes follow the task lifecycle in `docs/human/workflow.md`.

## Commands

- `/new-goal` — Research and create a goal with tasks
- `/work-task` — Execute a single task
CLAUDE_EOF

# ─── docs/human/specification.md ────────────────────────────────────────────

cat > docs/human/specification.md << SPEC_EOF
# Project Specification — ${PROJECT_NAME}

> **This file is human-owned.** Write freely. No format is enforced.
> Claude will read this to derive designs, tasks, and architecture — but will never edit it.

---

## Overview

<!-- What is this project? One or two sentences. -->

---

## Goals

<!-- What are the high-level goals? What does success look like? -->

---

## Key Features

<!-- List the features you want to build. Group loosely if helpful. -->

---

## Architecture & Technical Constraints

<!-- Language, framework, platform, performance requirements, etc. -->

---

## Out of Scope (for now)

<!-- Things you want to explicitly NOT build in the first version. -->

---

## Open Questions

<!-- Things you haven't decided yet — capture them here so they don't get lost. -->

---

## References & Inspirations

<!-- Links, docs, projects, or ideas you want to draw from. -->
SPEC_EOF

# ─── docs/human/workflow.md ─────────────────────────────────────────────────

cat > docs/human/workflow.md << 'WORKFLOW_EOF'
# Workflow

## Task Lifecycle

Every code change follows: **Research > Plan > Build > Document**.

No exceptions. No skipping phases.

## Goals and Tasks

- A **goal** is a deliverable outcome (epic). Contains multiple tasks.
- A **task** is a single-session unit of work (story). One feature, one refactor, or one fix.
- All functional code additions start with a goal.

## Task Types

- `agent` — executed by the agent. Default type.
- `human-action` — requires human action (e.g., editing human-owned docs). The agent presents what needs to change; the human confirms when done.

## IDs

- Goals: `GID-XXX` (globally unique, incrementing).
- Tasks: `TID-XXX` (globally unique across all goals, incrementing).
- Backlog items: `BID-XXX` (globally unique, incrementing).
- Before creating a new ID, scan `tasks/index.md` and relevant folders for the highest existing ID.

## Directory Layout

```
tasks/
  index.md                         # Dashboard
  goals/
    GID-XXX--short-name/
      goal.md                      # Goal definition + task table
      TID-XXX--short-name.md      # One file per task
  backlog/
    BID-XXX--short-name.md        # One file per backlog item
  archive/                         # Completed goals
```

## Goal Creation (`/new-goal`)

1. Read `specification.md`, `workflow.md`, and relevant design docs.
2. Research: identify scope, constraints, existing patterns.
3. Break work into tasks with dependencies.
4. Present the proposed breakdown to the user for review before creating any files.
5. On approval, create goal folder, `goal.md`, and all task files.
6. Task files must include Context and Research Notes sufficient to start work without re-researching.
7. Update `tasks/index.md`.

## Task Execution (`/work-task`)

1. Read `specification.md` and the task file.
2. Read relevant design docs in `docs/agent/`.
3. Write the Plan section in the task file.
   - Pause for approval only if complexity is high or task/design docs lack sufficient detail.
   - Otherwise proceed to Build.
4. Implement the plan.
5. Fill in Changes Made and Documentation Updates in the task file.
6. Update agent docs if the work introduced new designs, patterns, or architecture.
7. Update status in `goal.md` and `tasks/index.md`.
8. Commit: `TID-XXX: <description>`.

## Backlog

Backlog items capture inconsistencies, gaps, and bad smells discovered during any phase — in code, specs, or design docs.

- Log them immediately when discovered. Do not defer or forget.
- Each item gets a `BID-XXX` file in `tasks/backlog/` with enough context to act on it later.
- Add the item to the **Backlog** section of `tasks/index.md`.
- When resolved, move the `BID-XXX` file from `tasks/backlog/` to `tasks/archive/backlog/`, update its link in `tasks/index.md`, and move the row to the **Resolved Backlog** section.
- **Code issues**: fix opportunistically when working on a related task. Note the fix in the task's Changes Made.
- **Spec/doc issues**: prompt the user to resolve. Do not edit human-owned docs.

## Task Locking

- Only one agent session can work on a task at a time.
- Each task file has a Lock section: Session, Acquired, Expires.
- Locks expire after 30 minutes. Expired locks are auto-claimable.
- The agent acquires a lock before Plan and releases it after completion.

## Branches and Commits

- One branch per goal: `claude/GID-XXX--short-name`.
- One commit per task: `TID-XXX: <description>`.
- Merge to main when all tasks in a goal are complete.

## Documentation Rules

- **Human docs** (`docs/human/`): concise, scannable. Agent never edits.
- **Agent docs** (`docs/agent/`): exhaustive, descriptive. Updated after relevant tasks.
- **Task files**: self-contained. Enough context to begin work without reading other task files.

## Avoiding Documentation Sprawl

- Do not create standalone agent docs for individual workflow features. The workflow commands (`/new-goal`, `/work-task`) are the executable spec — enrich them directly.
- When adding a new behaviour: research existing files and commands first. Amend them rather than creating new docs.
- Create or amend commands in `.claude/commands/` to cover any behaviour that is frequent and repeatable.

## Archive

When a goal is fully complete:
1. Move its folder to `tasks/archive/`.
2. Move its row to the archive section of `tasks/index.md`.
WORKFLOW_EOF

# ─── tasks/index.md ─────────────────────────────────────────────────────────

cat > tasks/index.md << 'INDEX_EOF'
# Task Index

## Active Goals

| Goal | Title | Status | Progress |
|------|-------|--------|----------|

## Backlog

| ID | Summary | Category | Discovered During |
|----|---------|----------|-------------------|

## Resolved Backlog

| ID | Summary | Category | Discovered During |
|----|---------|----------|-------------------|

## Archive

| Goal | Title | Completed |
|------|-------|-----------|
INDEX_EOF

# ─── .claude/commands/new-goal.md ───────────────────────────────────────────

cat > .claude/commands/new-goal.md << 'NEWGOAL_EOF'
# New Goal

Create a new goal with tasks.

## Input

The user provides a description of what they want to achieve. If unclear, ask for clarification before proceeding.

## Steps

### Phase 1 — Research and Propose

1. Read `docs/human/specification.md`.
2. Read `docs/human/workflow.md`.
3. Read `docs/agent/design.md` and `docs/agent/architecture.md` if they exist.
4. Scan `tasks/index.md` and all folders under `tasks/goals/` to determine the next available `GID-XXX`.
5. Research: identify relevant code, existing patterns, constraints, and design considerations.
6. Break the work into tasks. For each task:
   - Assign a globally unique `TID-XXX` (scan all existing task files for the highest ID).
   - Assign a type: `agent` (default) or `human-action` (for tasks requiring human action on human-owned docs).
   - Define dependencies on other tasks.
   - Prepare Context and Research Notes with enough detail to start work without re-researching.
7. **Review gate**: present the proposed breakdown to the user. Do **not** create any files yet. Format:
   ```
   GID-XXX: <Title>

   | ID | Name | Type | Depends On |
   |----|------|------|------------|
   | TID-XXX | ... | agent | — |

   <one-line rationale per task if non-obvious>
   ```
   Wait for the user to approve, request changes, or redirect. Repeat until approved.

### Phase 2 — Create Files (after approval)

8. Create `tasks/goals/GID-XXX--<short-name>/goal.md` using the goal template below.
9. Create a `TID-XXX--<short-name>.md` file for each task using the task template below.
10. Update `tasks/index.md`.
11. Log any inconsistencies, gaps, or bad smells discovered during research as backlog items (`BID-XXX`) in `tasks/backlog/`.
12. Confirm to the user that all files have been created.

## Goal Template

```markdown
# GID-XXX: <Title>

## Objective

One sentence.

## Context

Why this goal exists. Links to spec sections if relevant.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-XXX | Name | agent | pending | — |

## Acceptance Criteria

- [ ] Criterion
```

## Backlog Item Template

```markdown
# BID-XXX: <Summary>

**Category:** spec-gap | design-inconsistency | code-smell | doc-gap
**Discovered During:** GID-XXX / TID-XXX / ad-hoc review

## Description

What the issue is. Be specific.

## Evidence

Where it was found — file paths, doc sections, spec contradictions.

## Suggested Resolution

How to fix it, or questions to ask the user.
```

## Task Template

```markdown
# TID-XXX: <Title>

**Goal:** GID-XXX
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Why this task exists. What goal it serves.

## Research Notes

Relevant files, existing patterns, constraints, design doc references.
Enough detail to begin work without re-researching.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
```
NEWGOAL_EOF

# ─── .claude/commands/work-task.md ──────────────────────────────────────────

cat > .claude/commands/work-task.md << 'WORKTASK_EOF'
# Work Task

Execute a single task.

## Input

Task ID (e.g., `TID-001`). Find the corresponding file under `tasks/goals/`.

## Steps

1. Read `docs/human/specification.md`.
2. Find and read the task file for the given ID.
3. Check the `Type` field. If `human-action`, follow the **Human-Action Flow** below. Otherwise continue.
4. **Lock check**: inspect the Lock section of the task file.
   - If `Session` is set and `Expires` is in the future → **abort**. Report: "Task is locked by session `<session>` until `<expiry>`. Wait for it to expire or for that session to release it."
   - If `Session` is `none`, the Lock section is absent, or `Expires` is in the past → proceed.
5. Read the parent `goal.md` for broader context.
6. Read relevant docs in `docs/agent/`.
7. **Acquire lock**: write the following to the Lock section of the task file before doing any further work:
   - `Session`: the current worktree name (e.g. `charming-meitner`); if not in a named worktree, use the current branch name.
   - `Acquired`: current UTC timestamp in ISO 8601 format.
   - `Expires`: `Acquired` + 30 minutes.
   - For long operations (Build phase), renew `Expires` (extend by 30 min) before it elapses to prevent false expiry.
8. **Plan**: write the Plan section in the task file.
   - If complexity is high or information is insufficient: present the plan and wait for approval.
   - Otherwise: proceed directly to Build.
9. **Build**: implement the plan.
10. Fill in "Changes Made" and "Documentation Updates" in the task file.
11. Update agent docs (`docs/agent/`) if relevant.
12. Update task status to `done` in the task file, `goal.md`, and `tasks/index.md`.
13. **Release lock**: set `Session: none`, `Acquired: —`, `Expires: —` in the task file.
14. Check for related backlog items (`tasks/backlog/`). Fix code-related ones opportunistically and note in Changes Made.
15. Log any new inconsistencies or gaps discovered during this task as backlog items.
16. Commit: `TID-XXX: <description>`.

## Human-Action Flow

For tasks with `Type: human-action`:

1. Read the task file's Context and Research Notes to understand what the human needs to do.
2. Present the required changes clearly: which file, which sections, what content to add or modify.
3. Wait for the user to confirm the changes are done.
4. Update task status to `done` in the task file, `goal.md`, and `tasks/index.md`.
5. Commit: `TID-XXX: <description>`.

## Branch

Work on the goal's branch: `claude/GID-XXX--short-name`. Create it if it doesn't exist.
WORKTASK_EOF

# ─── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "✓ Project scaffolded for: ${PROJECT_NAME}"
echo ""
echo "  Next steps:"
echo "  1. Fill in docs/human/specification.md with your project details"
echo "  2. git add -A && git commit -m 'Bootstrap project structure'"
echo "  3. Start working with /new-goal"
echo ""
