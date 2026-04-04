# TID-049: Migrate WorldMap to Load from MapData

**Goal:** GID-017
**Type:** agent
**Status:** done
**Depends On:** TID-046, TID-048

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`WorldMap.gd` is the central map loading/parsing class. Its `_init(map_name)` currently tries `BundledMaps`, then `res://assets/maps/*.txt`, then `user://maps/*.txt`, then generates a fallback. This task rewires `_init()` to call `MapRegistry.get_map()` and introduces `load_from_resource(data: MapData)` to populate internal state from a `MapData` resource.

The internal state model (2D tile/height arrays, entity dict arrays) is kept unchanged — downstream consumers (WorldScene, TerrainMath) are not touched in this task.

## Research Notes

**`WorldMap._init()` current flow** (`game_logic/world/WorldMap.gd`):
1. Check `BundledMaps.DATA.has(map_name)` → `load_from_string()`
2. Try `res://assets/maps/<name>.txt` → `load_from_string()`
3. Try `user://maps/<name>.txt` → `load_from_string()`
4. If name matches `dungeon_*` → `DungeonGen.generate(self)`
5. Else → generate default fallback map

**New `_init()` flow**:
1. Call `MapRegistry.get_map(map_name)` → returns `MapData` or `null`
2. If non-null → `load_from_resource(data)`
3. If null and name matches `dungeon_*` → `DungeonGen.generate()` returns a `MapData`, then `load_from_resource()`
4. Else → generate default fallback map inline

**`load_from_resource(data: MapData)`** — new method to add:
```gdscript
func load_from_resource(data: MapData) -> void:
    _width  = data.width
    _height = data.height
    spawn_x = data.spawn_x
    spawn_z = data.spawn_z
    # Rebuild tiles 2D array
    tiles = []
    for tz in range(_height):
        var row: Array[int] = []
        for tx in range(_width):
            row.append(data.tiles[tz * _width + tx])
        tiles.append(row)
    # Rebuild heights 2D array
    heights = []
    for tz in range(_height):
        var row: Array[int] = []
        for tx in range(_width):
            row.append(data.heights[tz * _width + tx])
        heights.append(row)
    # Populate entity arrays (convert typed Resources back to dicts)
    enemies = []
    for e in data.enemies:
        enemies.append({ "id": e.entity_id, "x": e.x, "z": e.z,
            "alive": e.alive, "tracking": false,
            "enemy_type": e.enemy_type, "enemy_deck": e.enemy_deck.duplicate() })
    # ... chests, doors, npcs, scrolls similarly
```

**`save_to_file()` current** — writes `.txt` to `user://maps/`. Change to:
```gdscript
func save_to_file(map_name: String) -> void:
    var data := to_map_data(map_name)
    ResourceSaver.save(data, "user://maps/%s.tres" % map_name)
```

**`to_map_data(map_name: String) -> MapData`** — inverse of `load_from_resource()`, needed for save and for MapRegistry backwards-compat shim:
```gdscript
func to_map_data(map_name: String) -> MapData:
    var data := MapData.new()
    data.map_name = map_name
    # ... populate from internal state
    return data
```

**Preload pattern** — per CLAUDE.md, use `preload` not `load` for scripts:
```gdscript
const MapDataRes = preload("res://game_logic/world/resources/MapData.gd")
const EnemyDataRes = preload("res://game_logic/world/resources/EnemyData.gd")
# etc.
```

**Key files:**
- `game_logic/world/WorldMap.gd` (~520 lines) — primary change target
- `scenes/world/WorldScene.gd` — consumer, should need no changes
- `game_logic/world/DungeonGen.gd` — generates maps (updated in TID-050)

## Plan

1. Rewrite `WorldMap._init()` to call `MapRegistry.get_map()` instead of `BundledMaps`.
2. Add `load_from_resource(data: Resource)` — populates 2D tile/height arrays and entity dicts from a MapData resource.
3. Add `to_map_data(p_map_name)` — inverse conversion, needed for save and for MapRegistry .txt fallback.
4. Rewrite `save_to_file(p_map_name)` — calls `to_map_data()` then `ResourceSaver.save()` to `.tres`.
5. Rewrite `list_map_names()` — delegates to `MapRegistry.list_map_names()`.
6. Add `p_skip_load` flag to `_init()` to allow MapRegistry's .txt fallback to create a WorldMap without triggering recursion.
7. Uncomment MapRegistry .txt fallback (uses skip_load + `load_from_file()` + `to_map_data()`).
8. Update `MapEditorScene._save_map()` to pass map name instead of `.txt` path.

## Changes Made

- **`game_logic/world/WorldMap.gd`**:
  - Removed `BundledMaps` preload; added preloads for `MapData`, `MapEnemy`, `MapChest`, `MapDoor`, `MapNpc`, `MapScroll` resource scripts.
  - `_init(p_name, p_skip_load=false)` — now calls `MapRegistry.get_map()` → `load_from_resource()`. Added `p_skip_load` param to avoid recursion when MapRegistry invokes WorldMap to parse legacy .txt files.
  - Added `load_from_resource(data: Resource)` — converts `MapData` flat PackedInt32Array grids to 2D arrays and entity Resources to world-coord dicts.
  - Added `to_map_data(p_map_name)` — inverse conversion; used by `save_to_file()` and MapRegistry .txt fallback.
  - `save_to_file(p_map_name: String)` — saves to `user://maps/<name>.tres` via `ResourceSaver.save()` (was: wrote `.txt` to a full path).
  - `list_map_names()` — now delegates to `MapRegistry.list_map_names()` (was: queried `BundledMaps.DATA` + scanned directories).
  - `load_from_string()` and `load_from_file()` preserved as compatibility shims.

- **`autoloads/MapRegistry.gd`** — Uncommented the legacy `.txt` fallback path. Uses `WorldMap.new(name, true)` (skip_load) + `load_from_file()` + `to_map_data()` to convert old user-saved `.txt` maps to MapData resources on the fly.

- **`scenes/ui/MapEditorScene.gd`** — `_save_map()` now calls `_world_map.save_to_file(_current_map_name)` (bare name) instead of constructing a `.txt` path.

## Documentation Updates

No agent doc changes required at this stage. `docs/agent/named-maps-and-dungeons.md` will be updated in TID-053 once the full migration is complete.
