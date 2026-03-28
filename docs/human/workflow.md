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
