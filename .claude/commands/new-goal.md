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
