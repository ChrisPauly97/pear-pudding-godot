# TID-268: Extract DayNightCycle and interaction handling

**Goal:** GID-072
**Type:** agent
**Status:** pending
**Depends On:** TID-267

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Day/night (~100 lines) and entity proximity/interaction (~300 lines combined) are self-contained clusters left in WorldScene after earlier extractions. This task splits them into focused components: DayNightCycle for environmental state management, ProximityFinder for entity detection, and a streamlined interaction handler in WorldScene. This improves testability and reusability (day/night system can be used in other scenes; proximity detection is a pure utility).

## Research Notes

- **Day/night cluster:** WorldScene.gd:78–89 (constants: `day_duration`, `DAY_NIGHT_INTERVAL`) and 953–1006 (`_update_day_night` — sun/moon rotation, lighting, GPU-write caching) → `scenes/world/DayNightCycle.gd`.
- **Proximity finding:** WorldScene.gd:850–933 — `_find_nearby_enemy`, `_find_nearby_chest` (scan chunk cache), `_find_nearby_door`, `_find_nearby_npc` (scan active data dicts), `_find_nearby_scroll` (array scan). Pure query logic, no scene-tree deps → extractable as ProximityFinder (could live in `game_logic/world/`).
- **Interaction handling:** WorldScene.gd:1026–1240 — `_process` (chunk updates, day/night tick, grass update, interaction throttle, position save), `_check_interactions` (UI prompts), `_unhandled_input` (menu/inventory/journal shortcuts), `_handle_interact` (door/enemy/chest/NPC/scroll branching).
- **Dead code to remove:** `flush_time_of_day()` at WorldScene.gd:379–380 is never called anywhere.
- **Camera note:** Camera follow and `_snap_to_pixel` (1007–1023) are small — leave in WorldScene. Note backlog BID-014 (camera stutter) exists; don't fix here, just don't make it worse.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
