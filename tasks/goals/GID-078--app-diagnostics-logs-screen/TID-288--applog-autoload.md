# TID-288: AppLog autoload — ring buffer & log methods

**Goal:** GID-078
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Godot's `print()` cannot be intercepted from GDScript. We introduce an `AppLog` autoload that provides `AppLog.info()`, `AppLog.warn()`, and `AppLog.error()` methods which store entries in a capped ring buffer (200 entries) and also call through to `print()` / `push_warning()` / `push_error()` so the editor console is unaffected.

`AppLog._ready()` connects to `GameBus` signals to auto-log the most meaningful game events without touching every existing call site.

## Research Notes

- Autoloads live in `autoloads/`. New autoloads need a `project.godot` entry under `[autoload]`.
- `autoloads/GameBus.gd` declares all cross-system signals — read it for the full list to decide which ones to log.
- Ring buffer pattern: `var _entries: Array[Dictionary] = []` capped at `MAX_ENTRIES = 200`; oldest entry removed when full.
- Each entry dict: `{ "ts": float, "level": String, "msg": String }` where `ts` = `Time.get_ticks_msec() / 1000.0`.
- Log levels: `"INFO"`, `"WARN"`, `"ERROR"`.
- Signal connections to log automatically (at minimum):
  - `GameBus.enemy_engaged` → INFO "Battle started: {enemy_type}"
  - `GameBus.battle_won` → INFO "Battle won"
  - `GameBus.battle_lost` → INFO "Battle lost"
  - `GameBus.save_written` (if it exists) → INFO "Save written"
  - `GameBus.hud_message_requested` → INFO "HUD: {msg}"
  - `GameBus.achievement_unlocked` → INFO "Achievement: {id}"
  - `GameBus.level_up` → INFO "Level up: {level}"
  - `GameBus.scene_entered` (if it exists) → INFO "Scene: {name}"
- Check `autoloads/GameBus.gd` for actual signal names before connecting.
- New `.gd` autoloads don't need `.uid` sidecars.

## Plan

1. Create `autoloads/AppLog.gd` — extends Node, registered as autoload.
   - `const MAX_ENTRIES: int = 200`
   - `var _entries: Array[Dictionary] = []` — each dict `{ts, level, msg}`
   - `func info(msg: String)` / `warn` / `error` — push to buffer + call print/push_warning/push_error
   - `func get_entries() -> Array[Dictionary]` — returns copy of buffer
   - `func clear()` — empties buffer
   - `_ready()` connects to GameBus signals: enemy_engaged, battle_won, battle_lost, hud_message_requested, achievement_unlocked, level_up, story_flag_set, story_scroll_collected, entered_named_map, world_event_started, world_event_ended, bounty_completed, siege_victory, siege_defeated, rival_encounter_won, weather_changed
2. Register `AppLog="*res://autoloads/AppLog.gd"` in `project.godot` after `GameBus` line.

## Changes Made

- Created `autoloads/AppLog.gd` — ring buffer (200 entries), `info/warn/error()` methods, `get_entries()`/`clear()`, auto-connects to 17 GameBus signals in `_ready()`.
- Registered `AppLog` in `project.godot` `[autoload]` section after `GameBus`.

## Documentation Updates

None needed for this task — agent docs for the diagnostics system will be created in TID-290.
