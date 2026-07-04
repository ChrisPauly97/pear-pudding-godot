# TID-409: Keybinding Persistence & Apply-on-Load

**Goal:** GID-109
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** claude/GID-109--keybindings-settings
**Acquired:** 2026-07-04T10:00:00Z
**Expires:** 2026-07-04T10:30:00Z

## Context

Before the UI can let players remap keys, there must be a storage and restore layer. This task adds the `keybindings` dict to `SaveManager.settings`, a helper to save/clear individual bindings, and an `_apply_keybindings()` call in `SceneManager._ready()` so overrides are applied to `InputMap` before the first scene loads.

## Research Notes

**SaveManager** (`autoloads/SaveManager.gd`):
- `settings: Dictionary` is the free-form bag for user prefs (lines 97–98).
- `get_setting(key, default)` / `set_setting(key, value)` are the read/write API (lines 1460–1464).
- `settings` is preserved across `new_game()` calls (line 420) — correct, binding prefs should survive new games.
- Persistence: `settings` is serialized into save JSON at key `"settings"` (line 942) and read back at line 833.

**SceneManager** (`autoloads/SceneManager.gd`):
- Already calls `_apply_audio_settings()` in `_ready()` (line 240/244). Follow the same pattern for keybindings.

**InputMap API** (Godot 4):
- `InputMap.action_get_events(action_name)` returns the current event list.
- `InputMap.action_erase_event(action_name, event)` removes one event.
- `InputMap.action_add_event(action_name, event)` adds one event.
- To replace only the first `InputEventKey` (leaving joypad events intact): iterate events, find `InputEventKey`, erase it, create a new `InputEventKey` with the saved `physical_keycode`, add it.

**Actions to cover** (13 total, from project.godot [input] section):
`move_up`, `move_down`, `move_left`, `move_right`, `interact`, `jump`,
`inventory`, `map_view`, `character`, `skill_tree`, `journal`, `mount`, `pause`

**Storage format** — `SaveManager.settings["keybindings"]` is a `Dictionary` mapping action name (String) → physical_keycode (int). Only overridden actions need an entry; missing entries mean "use project default".

**Default keycode map** — store as a `const` in `SceneManager` so Reset-to-Defaults can also call it:
```gdscript
const REBINDABLE_ACTIONS: Array[String] = [
    "move_up","move_down","move_left","move_right","interact","jump",
    "inventory","map_view","character","skill_tree","journal","mount","pause"
]
```

**Unit test** — `tests/unit/test_keybindings.gd`: verify that `set_setting("keybindings", {"interact": KEY_F})` followed by `_apply_keybindings()` results in `InputMap.action_has_event("interact", ...)` containing a key with `physical_keycode == KEY_F`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
