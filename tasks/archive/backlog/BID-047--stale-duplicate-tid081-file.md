# BID-047: Stale Duplicate TID-081 Task File

**Category:** code-smell
**Discovered During:** GID-116 research

## Description

`tasks/goals/GID-023--game-feel-polish/` contains two files for the same task ID:

- `TID-081--background-music-loop-integration.md` — `Status: done`, fully filled-in Plan/Changes Made/Documentation Updates.
- `TID-081--background-music-loop.md` — `Status: pending`, empty Plan/Changes Made, otherwise near-identical Context/Research Notes.

`goal.md`'s task table lists TID-081 as "Background music loop integration" / done, matching the first file. The second is an orphaned duplicate (likely an earlier draft that wasn't deleted when the task was renamed/refiled).

## Evidence

- `tasks/goals/GID-023--game-feel-polish/TID-081--background-music-loop-integration.md`
- `tasks/goals/GID-023--game-feel-polish/TID-081--background-music-loop.md`
- `tasks/goals/GID-023--game-feel-polish/goal.md` task table

## Suggested Resolution

Delete `TID-081--background-music-loop.md`. Assigned to GID-116 / TID-437 to fix opportunistically since that task is already touching audio docs/tasks.
