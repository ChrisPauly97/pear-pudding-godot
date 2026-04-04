# TID-050: Update DungeonGen to Output .tres

**Goal:** GID-017
**Type:** agent
**Status:** done
**Depends On:** TID-046, TID-049

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`DungeonGen.gd` currently generates dungeon maps by populating a `WorldMap` object in-memory and then writing a `.txt` file to `user://maps/dungeon_<seed>.txt` for persistence. After TID-049, `WorldMap` has a `to_map_data()` method. This task changes DungeonGen to save the dungeon as a `.tres` resource instead of a `.txt` file.

## Research Notes

**`DungeonGen.generate()` current signature** (`game_logic/world/DungeonGen.gd`):
```gdscript
static func generate(world_map: WorldMap, seed_str: String) -> void:
    # Fills world_map.tiles, world_map.enemies, etc. in-place
    # Calls world_map.save_to_file("dungeon_" + seed_hash) at the end
```

After TID-049, `WorldMap.save_to_file()` already saves `.tres`. So DungeonGen may need no change if it calls `world_map.save_to_file()`. Verify this during the task.

**WorldMap loading path for dungeons** — in `WorldMap._init()`, if `MapRegistry.get_map()` returns null and name matches `dungeon_*`:
1. Check `user://maps/<name>.tres` exists → load it (handled by `MapRegistry.get_map()` fallback)
2. If not → call `DungeonGen.generate()` → populates world_map → `save_to_file()` → now saves `.tres`

**Possible additional change**: If DungeonGen currently calls `save_to_file()` which writes `.txt`, and TID-049 changes `save_to_file()` to write `.tres`, this task may reduce to just verifying the integration works correctly and adding a test.

However, if DungeonGen has its own file writing logic separate from `save_to_file()`, that must be updated here.

**Check during research phase of this task**: read `DungeonGen.gd` fully to confirm which path it uses.

**Key files:**
- `game_logic/world/DungeonGen.gd` (~200 lines) — primary change target
- `game_logic/world/WorldMap.gd` — `save_to_file()` updated in TID-049
- `autoloads/MapRegistry.gd` — fallback loading from `user://maps/`

## Plan

1. In `DungeonGen.generate()`, change `_WorldMap.new(p_name)` to `_WorldMap.new(p_name, true)` to skip the default-map fallback (no wasteful `_build_default_map()` + spurious warning).
2. Add `map.save_to_file(p_name)` at the end of `generate()` before returning, so the dungeon is persisted as `user://maps/<name>.tres`.
3. In `WorldScene._ready()`, check `MapRegistry.get_map(map_name)` before regenerating a dungeon — if a saved .tres exists, load it via `WorldMap.new(map_name)`; otherwise call `DungeonGen.generate()`.

## Changes Made

- **`game_logic/world/DungeonGen.gd`**:
  - Changed `_WorldMap.new(p_name)` → `_WorldMap.new(p_name, true)` to use the `p_skip_load` flag added in TID-049, preventing the fallback default-map build.
  - Added `map.save_to_file(p_name)` before `return map`, persisting the generated dungeon to `user://maps/<name>.tres`.

- **`scenes/world/WorldScene.gd`**:
  - Updated the dungeon branch to call `MapRegistry.get_map(map_name)` first. If the .tres exists (re-entry), loads via `WorldMap.new(map_name)`. If not (first visit), calls `DungeonGen.generate()` which generates and saves.

## Documentation Updates

No doc changes in this task; `docs/agent/named-maps-and-dungeons.md` will be fully rewritten in TID-053.
