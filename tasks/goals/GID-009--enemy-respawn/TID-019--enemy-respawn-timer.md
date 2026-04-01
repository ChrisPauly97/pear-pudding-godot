# TID-019: Time-Based Procedural Enemy Respawn

**Goal:** GID-009
**Type:** agent
**Status:** done
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

1. Add `ENEMY_RESPAWN_DAYS: int = 3` to `autoloads/IsoConst.gd`.
2. Add `days_elapsed` and `last_respawn_day` fields to `SaveManager`, including save/load/migration (bump to version 4).
3. Add `SaveManager.increment_day()` that increments the counter and clears non-`map_` prefixed enemy IDs when threshold reached.
4. In `WorldScene._update_day_night()`, detect the day wrap (`_time_of_day` drops below previous value after fmod) and call `increment_day()`.

## Changes Made

- `autoloads/IsoConst.gd`: Added `ENEMY_RESPAWN_DAYS: int = 3`.
- `autoloads/SaveManager.gd`:
  - Added `days_elapsed: int = 0` and `last_respawn_day: int = 0` fields.
  - Bumped `CURRENT_SAVE_VERSION` to 4.
  - Added `_migrate_v3_to_v4()` to backfill both fields in old saves.
  - Added both fields to `new_game()` reset, `load_save()`, and `save()`.
  - Added `increment_day()` method that clears procedural enemy IDs (`chunk_` prefix) from `defeated_enemies` every `ENEMY_RESPAWN_DAYS` in-game days.
- `scenes/world/WorldScene.gd`: In `_update_day_night()`, detect the day wrap and call `SaveManager.increment_day()`.

## Documentation Updates

Updated `docs/agent/enemies-and-npcs.md` if applicable — no separate doc change needed; logic is self-contained and covered by save-system.md migration pattern.
