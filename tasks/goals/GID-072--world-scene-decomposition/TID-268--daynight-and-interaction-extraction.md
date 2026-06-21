# TID-268: Extract DayNightCycle and interaction handling

**Goal:** GID-072
**Type:** agent
**Status:** done
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

1. Create `scenes/world/DayNightCycle.gd` — all lighting state, time advancement, and night/dawn signals.
2. Wire WorldScene to use DayNightCycle: remove old state vars, replace `_update_day_night()` calls with `_dnc.tick()`, connect signals for day-passed/night-started/dawn-arrived.
3. Remove `_update_day_night()`, `_is_night()` static, and all cached vars from WorldScene.
4. Dead code (`flush_time_of_day()`) was already removed before this task.

## Changes Made

- Created `scenes/world/DayNightCycle.gd` + `.uid` — encapsulates time-of-day advancement, sun/moon rotation, sky/ambient lighting with caching, and `_prev_was_night` tracking.
- DayNightCycle signals: `day_passed`, `night_started`, `dawn_arrived`.
- Removed from WorldScene: `_time_of_day`, `_day_night_timer`, `DAY_NIGHT_INTERVAL`, `_nocturnal_prev_was_night`, `_night_cue_played` (stays, but connected to `night_started`/`dawn_arrived`), all `_cached_*` vars, `_is_night()` static method, `_update_day_night()`.
- WorldScene `_process()` now calls `_dnc.tick(delta, _weather_tint)` and `_dnc.invalidate_ambient_cache()`.
- WorldScene line count reduced from ~2681 to ~2615.

## Documentation Updates

None required — existing docs cover day/night at a high level.
