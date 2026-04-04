# TID-051: Update Map Editor to Save/Load .tres

**Goal:** GID-017
**Type:** agent
**Status:** done
**Depends On:** TID-049

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The in-game Map Editor (`MapEditorScene.gd`) saves maps to `user://maps/<name>.txt` and loads them using `WorldMap`. After TID-049, `WorldMap.save_to_file()` writes `.tres` instead of `.txt`. This task updates any remaining `.txt`-specific logic in the editor and ensures load paths look for `.tres` first.

## Research Notes

**`MapEditorScene.gd`** save/load pattern (from exploration):
- Save: calls `world_map.save_to_file(map_name)` — if TID-049 updates this to write `.tres`, the editor call may already work correctly
- Load: calls something like `WorldMap.new(map_name)` which now uses MapRegistry — should work

**Check during research phase**: read `MapEditorScene.gd` to find:
1. Any direct `FileAccess.open(..., ".txt")` calls
2. Any hardcoded `.txt` extension in filenames
3. The load/save UI flow (button labels, file pickers, map name input)
4. Whether the editor lists existing maps from `user://maps/` — if so, the glob pattern must change from `*.txt` to `*.tres`

**Expected changes** (may be minimal if WorldMap wrappers are used throughout):
- Any `user://maps/*.txt` file listing → change to `user://maps/*.tres`
- Any `FileAccess` direct writes of `.txt` format → remove or delegate to `WorldMap.save_to_file()`
- Map name display: strip `.tres` extension instead of `.txt` when listing saved maps

**Key files:**
- `scenes/ui/MapEditorScene.gd` (~400 lines) — primary change target
- `game_logic/world/WorldMap.gd` — `save_to_file()` updated in TID-049

## Plan

1. Audit MapEditorScene.gd for any remaining `.txt`-specific code.
2. Fix `_new_map_dialog()`: `WorldMap.new(name)` now triggers `_build_default_map()` internally for unknown names, then the dialog called it again — double build. Use `WorldMap.new(name, true)` (skip_load) so only the explicit `_build_default_map()` call runs.
3. Confirm all other paths (`_load_map`, `_save_map`, `_show_map_list`) are correct.

## Changes Made

- **`scenes/ui/MapEditorScene.gd`**: In `_new_map_dialog()`, changed `WorldMap.new(name)` → `WorldMap.new(name, true)`. This uses the `p_skip_load` flag to avoid `MapRegistry.get_map()` being called (and the fallback `_build_default_map()` running twice when the name is unknown). The explicit `_build_default_map()` call immediately after handles initialization.
- No other changes were needed: `_save_map()` was already updated in TID-049 to call `save_to_file(_current_map_name)` (saves .tres); `_load_map()` uses `WorldMap.new()` which delegates to MapRegistry; `_show_map_list()` uses `WorldMap.list_map_names()` which delegates to MapRegistry.

## Documentation Updates

None required at this stage.
