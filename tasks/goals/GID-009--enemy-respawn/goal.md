# GID-009: Enemy Respawn System

## Objective

Respawn procedural-world enemies after a set number of in-game days so the world never permanently empties.

## Context

`SaveManager.defeated_enemies` permanently tracks every defeated enemy ID. Once cleared, enemies in procedural chunks never respawn, making the world increasingly sparse on a long playthrough. Named-map enemies (story characters, dungeon guards) should stay defeated; only procedural-world enemies should reset on a timer. The in-game day cycle (`time_of_day` 0–1, period 600s) provides a clean hook.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-019 | Time-based procedural enemy respawn | agent | pending | — |

## Acceptance Criteria

- [ ] After N in-game days (configurable constant, default 3), procedural-world enemy IDs are cleared from `defeated_enemies`
- [ ] Named-map enemy IDs are never cleared (identified by a naming convention prefix, e.g. `map_*`)
- [ ] Respawn clears enemies silently in the background — no visual pop or save corruption
- [ ] Respawn day count persists across save/load
- [ ] Existing enemies already in the world (loaded chunks) are not affected mid-session — only newly visited chunks see respawned enemies
