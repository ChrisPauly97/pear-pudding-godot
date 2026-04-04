# TID-051: Update Map Editor to Save/Load .tres

**Goal:** GID-017
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
