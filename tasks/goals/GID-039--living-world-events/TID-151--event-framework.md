# TID-151: WorldEventManager Autoload + Save Fields + GameBus Signals

**Goal:** GID-039
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The scheduler that gives the world a heartbeat. A single autoload tracks per-event cooldowns, fires events on randomized intervals, and persists timers so cooldowns survive restarts. The three concrete events (TID-152..154) register against this framework.

## Research Notes

- **New autoload:** `autoloads/WorldEventManager.gd`, registered in `project.godot` after SaveManager (it reads save state). Core:
  - `register_event(id: String, min_interval: float, max_interval: float, spawn: Callable, cleanup: Callable)` — events call this at startup (from a single `WorldEvents.gd` init script preloaded by WorldScene, keeping the autoload generic).
  - `_process(delta)` — accumulate time only while the player is in the **infinite world** (not named maps/dungeons/battles). Determine context via SceneManager state or a GameBus signal on map enter/exit — check `docs/agent/ui-and-scene-management.md` for how scene context is tracked.
  - When an event's timer expires, roll the next interval, call `spawn`, emit `GameBus.world_event_started(id)`.
  - `end_event(id)` — calls `cleanup`, emits `world_event_ended(id)`, restarts the cooldown.
- `autoloads/GameBus.gd` — add `world_event_started(event_id: String)` and `world_event_ended(event_id: String)` signals. Update `docs/agent/signals-and-constants.md` signal table.
- `autoloads/SaveManager.gd` — add `world_events: Dictionary` (event_id → `{elapsed: float, active: bool}`) with migration. Persist elapsed time on the dirty-flag cycle so cooldowns survive restarts; an event that was `active` at save time simply restarts its cooldown on load (do not try to respawn mid-event state in v1).
- **Only one event active at a time** — simpler, and prevents a boss + merchant + shower pileup. The scheduler skips firing while any event is active.
- **Spawn positioning helper:** Most events need "a walkable tile near the player but off-screen". Add a static helper `find_spawn_tile(player_pos, min_dist, max_dist) -> Vector3` using `InfiniteWorldGen`/chunk tile lookups (see `docs/agent/world-generation.md` for how entity spawn placement currently works in chunks).
- **Tests:** Headless test for interval rolling, single-active-event rule, and save round-trip of `world_events`.
- `docs/agent/world-generation.md` — document the event layer.

## Plan

1. Add `world_event_started(event_id: String)` and `world_event_ended(event_id: String)` signals to `GameBus.gd`.
2. Add `world_events: Dictionary` field to `SaveManager.gd` with migration v17→v18 (field default `{}`); persist in save/load.
3. Create `autoloads/WorldEventManager.gd` with:
   - Inner class `_EventReg` (id, min/max_interval, spawn/cleanup Callable, elapsed, next_interval, active)
   - `var _events: Dictionary`, `var _active_event_id: String`, `var _in_battle: bool`, `var _rng: RandomNumberGenerator`
   - `_ready()`: randomize rng, connect GameBus signals to set `_in_battle`
   - `register_event(id, min_i, max_i, spawn_fn, cleanup_fn)`: create reg, roll interval, restore elapsed from SaveManager.world_events
   - `_process(delta)`: skip if `_in_battle` or `SceneManager.current_map != "main"`, else call `_tick(delta)`
   - `_tick(delta)`: accumulate elapsed, fire first event whose elapsed >= next_interval (only if none active)
   - `_fire_event(id, reg)`: set active, roll next interval, call spawn, emit signal, persist
   - `end_event(id)`: call cleanup, clear active, emit signal, persist
   - `_persist_events()`: write all elapsed/active state to SaveManager.world_events + mark_dirty
   - `static find_spawn_tile(player_pos, min_dist, max_dist, world_seed) -> Vector3`: try 30 random angles/distances, check tile via InfiniteWorldGen.generate_chunk_data_only, return first grass tile
4. Register `WorldEventManager` in `project.godot` after `SaveManager`.
5. Write `tests/unit/test_world_event_manager.gd` covering: interval rolling in range, event fires after elapsed >= interval, no fire while another is active, end_event clears active, save round-trip of elapsed.
6. Add test suite to `tests/runner.gd`.
7. Update `docs/agent/world-generation.md` with event layer section.

## Changes Made

- `autoloads/GameBus.gd` — added `world_event_started(event_id: String)` and `world_event_ended(event_id: String)` signals.
- `autoloads/SaveManager.gd` — added `world_events: Dictionary = {}` field; reset in `new_game()`; bumped `CURRENT_SAVE_VERSION` from 17 to 18 with `_migrate_v17_to_v18()` that backfills the field; added save/load round-trip.
- `autoloads/WorldEventManager.gd` — new autoload with inner class `_EventReg`, `register_event()`, `_tick()`, `_fire_event()`, `end_event()`, `is_event_active()`, `get_active_event_id()`, `_persist_events()`, and `static find_spawn_tile()`. Uses `get_node_or_null("/root/GameBus")` and `get_node_or_null("/root/SceneManager")` (stored as `Node` vars) to avoid compile-time autoload identifier failures during GDScript's reload phase.
- `project.godot` — registered `WorldEventManager` autoload after `SaveManager`.
- `tests/unit/test_world_event_manager.gd` — new 21-test suite covering interval rolling, event firing, single-active-event rule, `end_event` cleanup, and save round-trip. Lambda captures use Array wrappers (`[0]`) for GDScript 4.4.1 mutable-capture semantics. Persistence tests guard with `pending()` when `save_manager` is unavailable in headless mode.
- `tests/runner.gd` — added test suite to `SUITES` array.
- `tests/unit/test_spire_run.gd` — updated `test_apply_migrations_reaches_v17_from_v16` (renamed to `test_apply_migrations_reaches_current_from_v16`) to expect `CURRENT_SAVE_VERSION` (now 18) instead of hard-coded 17.

## Documentation Updates

- `docs/agent/world-generation.md` — added "Living World Events" section documenting WorldEventManager API, scheduling rules, and GameBus signals.
- `docs/agent/signals-and-constants.md` — added `world_event_started` and `world_event_ended` rows to the Signal Reference Table.
