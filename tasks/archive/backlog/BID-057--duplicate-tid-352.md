# BID-057: Duplicate TID-352 across two goals

Category: doc-gap
Discovered during: GID-124 merge-conflict resolution (ID uniqueness audit)

## Summary

Two different completed tasks share TID-352:

- `tasks/goals/GID-096--coop-world-sync/TID-352--avatar-map-awareness.md`
- `tasks/goals/GID-097--dedicated-server/TID-352--dedicated-server-mode.md`

`docs/human/workflow.md` requires TIDs to be globally unique. Both predate this
branch and both exist on `main`.

## Why it wasn't fixed here

Both tasks are complete and referenced from commit messages, `goal.md` tables
and CLAUDE.md's Bug Fix Learnings by ID. Renumbering one would invalidate those
references for no functional gain, so this is filed rather than fixed.

## Suggested resolution

Either leave it and note the collision in both files' headers, or renumber the
GID-097 one to a free ID and sweep the references. Prefer the former unless a
tool starts keying on TID uniqueness.

## Related

The same audit found a live collision between this branch and `main` (both used
GID-123 + TID-466/467/468). That one **was** fixed — this branch renumbered to
GID-124/125 and TID-469-474, since it was the unmerged side.

Worth considering: a cheap `tests/unit/` guardrail asserting TID/GID/BID
uniqueness across `tasks/`, in the spirit of `test_gamebus_signal_coverage.gd`.
It would have caught the GID-123 collision the moment it was created rather than
at merge time.

## Resolution (2026-08-03)

Took the "leave it" option: added a cross-reference note to both TID-352
files' headers pointing at each other and at this item. Also added the
suggested guardrail: `tests/unit/test_task_id_uniqueness.gd` (3 tests) scans
`tasks/goals/` and `tasks/backlog/`+`tasks/archive/backlog/` for
TID-/GID-/BID- prefixed filenames and asserts no duplicates except a
documented allowlist (currently just `TID-352`). It would have caught the
GID-123 collision this item mentions, and will catch any future one at test
time instead of merge time.
