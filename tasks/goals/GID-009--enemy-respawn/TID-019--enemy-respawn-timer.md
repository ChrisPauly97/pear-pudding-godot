# TID-019: Time-Based Procedural Enemy Respawn

**Goal:** GID-009
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Enemies defeated in the procedural world are tracked in `SaveManager.defeated_enemies`. This task adds a day counter to SaveManager and clears only procedural enemy IDs from that set when the counter reaches the respawn threshold.

## Research Notes

**Relevant files:**
- `autoloads/SaveManager.gd` — `defeated_enemies: Array[String]`, `time_of_day: float`, `mark_dirty()`, save/load dict; add `days_elapsed: int` and `last_respawn_day: int` fields
- `scenes/world/WorldScene.gd` — `_process()` updates `time_of_day` each 0.5 s; day boundary (time_of_day wraps from ~1.0 to 0.0) is the trigger point
- `autoloads/IsoConst.gd` — add `ENEMY_RESPAWN_DAYS: int = 3` constant here

**Naming convention for procedural vs named-map enemies:**
- Named-map enemies are spawned with IDs like `"map_madrian_enemy_0"` (prefix `map_`)
- Procedural enemies use chunk-based IDs like `"chunk_4_-2_enemy_1"` (prefix `chunk_`)
- Respawn logic filters: only clear IDs that do NOT start with `"map_"`

**Approach:**
1. Add `ENEMY_RESPAWN_DAYS: int = 3` to `IsoConst.gd`
2. Add `days_elapsed: int = 0` and `last_respawn_day: int = 0` to `SaveManager` (saved/loaded/migrated)
3. In `WorldScene._process()`, detect the day wrap (time_of_day crosses 0 from above) and call `SaveManager.increment_day()`
4. `SaveManager.increment_day()`:
   - Increments `days_elapsed`
   - If `days_elapsed - last_respawn_day >= IsoConst.ENEMY_RESPAWN_DAYS`:
     - Filter `defeated_enemies` to keep only IDs starting with `"map_"`
     - Set `last_respawn_day = days_elapsed`
     - `mark_dirty()`

**No chunk reload needed** — chunks already in memory keep their spawned state; only new chunk visits see respawned enemies because `InfiniteWorldGen` checks `defeated_enemies` at spawn time.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
