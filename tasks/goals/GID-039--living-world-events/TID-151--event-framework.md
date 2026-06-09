# TID-151: WorldEventManager Autoload + Save Fields + GameBus Signals

**Goal:** GID-039
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
