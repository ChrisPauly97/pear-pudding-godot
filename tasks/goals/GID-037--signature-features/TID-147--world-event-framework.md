# TID-147: Living World Event Framework (Scheduler, Save Fields, Signals)

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The infinite world is scenery between battles. A lightweight event scheduler that fires named events on a real-time or in-game-time interval gives the world a heartbeat — things happen without player action. This task builds the scheduler and save plumbing; TID-148 adds the three concrete events.

## Research Notes

- **WorldEventManager autoload (new):** A new autoload `WorldEventManager.gd` with a `_process()` loop. Tracks `time_since_last_event: float` per event type. Fires events by emitting `GameBus.world_event_started(event_id: String)`.
- **Save fields:** Add `world_events: Dictionary` to `SaveManager` — keyed by event_id, value = `{ "last_fired_time": float, "active": bool, ... }`. Apply migration.
- **Event types registered:** Each event type is a `WorldEventDef` dict (or inner class): `{ id, min_interval_sec, max_interval_sec, spawn_func: Callable }`. TID-148 registers three.
- `autoloads/GameBus.gd` — add `world_event_started(event_id: String)` and `world_event_ended(event_id: String)` signals.
- `autoloads/SaveManager.gd` — add `world_events` field with sane defaults (all events inactive, last_fired = 0.0).
- **Minimap integration:** `scenes/world/Minimap.gd` listens to `world_event_started`; for the roaming boss event it places a red dot at the event's world position.
- `docs/agent/signals-and-constants.md` — GameBus signal list to update.
- `docs/agent/world-generation.md` — document event scheduler as a world layer.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
