# BID-046: Backlog index drift — duplicate BID-018, unindexed items, one already-fixed item still open

**Category:** doc-gap
**Discovered During:** GID-115 goal research (bug triage pass, 2026-07-08)

## Description

The backlog directory and the `tasks/index.md` Backlog table have drifted apart:

1. **Duplicate ID:** two files share BID-018 —
   `BID-018--enemy-registry-uses-dirAccess-android.md` and
   `BID-018--test-runner-preexisting-suite-failures.md`. IDs are supposed to be
   globally unique.
2. **Unindexed items:** BID-018 (both), BID-019
   (`bestiary-completion-test-failures`) and BID-021 (`dungeon-gen-test-failures`)
   exist in `tasks/backlog/` but have no row in `tasks/index.md`'s Backlog table.
3. **Already fixed but still open:** BID-018 (enemy registry DirAccess) is resolved
   at HEAD — `autoloads/EnemyRegistry.gd` now uses one `preload()` const per enemy
   `.tres` (no `DirAccess`/`ResourceLoader.load()` remain). The file should move to
   `tasks/archive/backlog/`.
4. **Likely stale:** BID-019's premise ("bestiary completion reward logic may not be
   wired up") was checked during GID-115 research — `SaveManager._check_bestiary_complete()`
   (line 1832) does grant 500 coins + soul_harvest + story flag, and
   `record_enemy_defeated` triggers it (line 1817). The 8 test failures are almost
   certainly the BID-018-test-runner class of headless-environment issue (no editor
   scan → empty registries), not a gameplay bug. Needs a verified headless run to
   confirm, then BID-019 can be folded into the test-runner item or closed.

## Evidence

- `ls tasks/backlog/` vs the Backlog table in `tasks/index.md`
- `grep -c "DirAccess\|ResourceLoader.load" autoloads/EnemyRegistry.gd` → 0
- `autoloads/SaveManager.gd:1817,1832-1840`

## Suggested Resolution

Renumber `BID-018--test-runner-preexisting-suite-failures.md` to a free ID (or merge
BID-019/BID-021 into it as one "headless runner needs a prior editor scan" item),
archive the enemy-registry BID-018 as resolved, and add index rows for whatever
remains open.
