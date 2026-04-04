# Named Maps and Dungeons

## Key Features

- Hand-authored maps stored as typed Godot `.tres` resource files in `assets/maps/`
- `MapData` resource class encodes tile grid, sparse heights, player spawn, and entity lists
- Six built-in maps preloaded by `MapRegistry` autoload — guaranteed in Android APK/PCK
- Procedural dungeon generation via `DungeonGen` (seeded, deterministic); persisted as `.tres` on first generation
- Map stack navigation: entering a door pushes the current map; exiting pops back to the return door
- Legacy `load_from_string()` shim in `WorldMap` supports old user-saved `.txt` maps during transition

---

## Resource Class Hierarchy

All map data is stored in typed `extends Resource` classes. Each class has a `.uid` sidecar file for Android export tracking.

| Class | File | Purpose |
|---|---|---|
| `MapData` | `game_logic/world/resources/MapData.gd` | Top-level map resource; owns tile grids and entity arrays |
| `MapEnemy` | `game_logic/world/resources/MapEnemy.gd` | Enemy tile position + type key |
| `MapChest` | `game_logic/world/resources/MapChest.gd` | Chest tile position + card ID list |
| `MapDoor` | `game_logic/world/resources/MapDoor.gd` | Door tile position + destination map + flag key |
| `MapNpc` | `game_logic/world/resources/MapNpc.gd` | NPC tile position + dialogue + npc_type + flag |
| `MapScroll` | `game_logic/world/resources/MapScroll.gd` | Scroll tile position + scroll_id + flag key |
| `MapTrigger` | `game_logic/world/resources/MapTrigger.gd` | Scripted trigger tile position + event_id (extensibility) |
| `MapRegion` | `game_logic/world/resources/MapRegion.gd` | Named rectangular region (extensibility) |

### `MapData` fields

```gdscript
@export var map_name: String = ""
@export var width: int = 100
@export var height: int = 100
@export var tiles: PackedInt32Array = PackedInt32Array()    # row-major: tz*width+tx
@export var heights: PackedInt32Array = PackedInt32Array()  # same indexing
@export var spawn_x: int = 5
@export var spawn_z: int = 5
@export var enemies: Array[Resource] = []   # cast to MapEnemy at load time
@export var chests: Array[Resource] = []    # cast to MapChest at load time
@export var doors: Array[Resource] = []     # cast to MapDoor at load time
@export var npcs: Array[Resource] = []      # cast to MapNpc at load time
@export var scrolls: Array[Resource] = []   # cast to MapScroll at load time
@export var triggers: Array[Resource] = []  # cast to MapTrigger at load time (future)
@export var regions: Array[Resource] = []   # cast to MapRegion at load time (future)
@export var music_track: String = ""
@export var difficulty: int = 0
@export var author: String = ""
@export var version: int = 1
```

Entity positions in `.tres` files are stored in **tile coordinates** (`tile_x`, `tile_z`). `WorldMap.load_from_resource()` converts these to **world coordinates** (`x = float(tile_x) * TILE_SIZE`) at load time.

---

## How It Works

### Loading: `MapRegistry` → `WorldMap`

`MapRegistry` (`autoloads/MapRegistry.gd`) is the single source of truth for named maps.

**Load priority in `MapRegistry.get_map(map_name)`:**
1. **Bundled maps** — `const` preloads in `MapRegistry.gd`; always available on all platforms including Android.
2. **`user://maps/<name>.tres`** — editor-saved or DungeonGen-saved maps.
3. **`user://maps/<name>.txt`** — legacy shim: parses old `.txt` via `WorldMap.load_from_file()` + `to_map_data()`, converts on the fly. Write-once: next `save_to_file()` produces `.tres`.

**`WorldMap._init(p_name, p_skip_load=false)`** calls `MapRegistry.get_map()` then `load_from_resource()`. If no map is found, `_build_default_map()` generates a placeholder and sets `is_fallback = true`. Pass `p_skip_load=true` when creating a blank WorldMap for immediate in-place population (DungeonGen, New Map dialog).

**`WorldMap.load_from_resource(data: Resource)`** unpacks `MapData`:
- Flat `PackedInt32Array` tiles/heights → 2D `Array[Array]` (100×100)
- Entity Resources (tile coords) → entity dicts (world coords); runtime state added (alive, opened, enemy_deck)

### Saving: `WorldMap.save_to_file(map_name)`

Calls `to_map_data(map_name)` then `ResourceSaver.save(data, "user://maps/<name>.tres")`. The `.tres` file is saved to `user://maps/`, not `res://assets/maps/` — built-in maps are only committed from source.

### Dungeon Generation: `DungeonGen.gd`

`DungeonGen.generate(p_name, dungeon_seed)`:
1. Creates `WorldMap(p_name, true)` (blank, no MapRegistry lookup).
2. Fills 80×60 tile area with walls, carves rooms, connects corridors.
3. Places enemies (difficulty scales with seed-derived depth), a chest, and an exit door.
4. Calls `map.save_to_file(p_name)` → writes `user://maps/dungeon_<seed>.tres`.
5. Returns the WorldMap.

**`WorldScene`** checks `MapRegistry.get_map(map_name)` before entering a dungeon:
- If `.tres` exists → `WorldMap.new(map_name)` loads from saved resource (no regeneration).
- If not → `DungeonGen.generate()` generates, saves, and returns a fresh WorldMap.

### Map Stack Navigation

`SceneManager` maintains `map_stack: Array[Dictionary]` in `SaveManager`:

```
enter_map(map_name, target_door_id):
  push { current_map, current_player_pos, return_door_id } onto stack
  load new WorldMap
  teleport player to door matching target_door_id (or spawn if no id)

exit_map_via_door(door):
  if stack empty → do nothing
  pop top entry
  restore previous WorldMap
  teleport player to saved return_door_id tile
```

Supports arbitrary nesting: overworld → ruin dungeon → inner chamber → …

---

## Adding a New Built-in Map

1. Create `assets/maps/<name>.tres` (use the in-game Map Editor, then copy from `user://maps/`, or write a converter script).
2. Create `assets/maps/<name>.tres.uid` with `uid://` + 12 random lowercase alphanumeric chars.
3. Add to `autoloads/MapRegistry.gd`:
   ```gdscript
   const _NAME := preload("res://assets/maps/<name>.tres")
   ```
   And add `"<name>": _NAME` to `_BUNDLED`.
4. Commit both files. No bundling step needed — Godot's export system follows the `preload` dependency.

---

## Adding a New Entity Type

1. Create `game_logic/world/resources/MapFoo.gd` (extends Resource, `@export` fields for tile_x, tile_z, and type-specific data).
2. Create `game_logic/world/resources/MapFoo.gd.uid`.
3. Add `@export var foos: Array[Resource] = []` to `MapData.gd`.
4. In `WorldMap.gd`:
   - Add `const _MapFoo = preload("res://game_logic/world/resources/MapFoo.gd")`.
   - In `load_from_resource()`: iterate `md.foos`, cast each to `_MapFoo`, append a dict with world coords to `self.foos`.
   - In `to_map_data()`: iterate `self.foos` dicts, create `_MapFoo` instances, append to `md.foos`.
5. Add `var foos: Array[Dictionary] = []` to WorldMap and any `find_nearby_foo()` helpers.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **WorldScene** | Consumer | Calls `WorldMap.new(name)` (named maps) or `DungeonGen.generate()` (dungeons); passes `WorldMap.get_tile` as a `Callable` to `TerrainMath` |
| **TerrainMath** | Mesh builder | Accepts `Callable` tile lookup from `WorldMap.get_tile`; builds height field + terrain mesh |
| **MapRegistry** | Loader | Autoload; the only path through which named maps are loaded at runtime |
| **SceneManager** | Orchestrator | Owns map stack; calls `enter_map()` / `exit_map_via_door()` on DOOR interaction |
| **SaveManager** | Persistence | `map_stack`, `current_map`, `player_x/z` saved to `save.json` |
| **MapEditorScene** | Editor | Calls `WorldMap.new(name)` to load, `save_to_file(name)` to save `.tres` to `user://maps/` |
| **EnemyRegistry** | Entity typing | `WorldMap.load_from_resource()` resolves `MapEnemy.enemy_type` via `EnemyRegistry.get_deck()` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Built-in map resources | `assets/maps/*.tres` + `*.tres.uid` | 6 maps; preloaded by MapRegistry |
| `MapData.gd` + siblings | `game_logic/world/resources/` | Resource schema files; each needs a `.uid` sidecar |
| `WorldMap.gd` | `game_logic/world/WorldMap.gd` | Runtime loader; exposes `get_tile(x,z)` Callable |
| `MapRegistry.gd` | `autoloads/MapRegistry.gd` | Autoload; registered in `project.godot` |
| `DungeonGen.gd` | `game_logic/world/DungeonGen.gd` | Procedural dungeon writer; only called if dungeon not in MapRegistry |
| User maps directory | `user://maps/` | Created at runtime; stores editor-saved + DungeonGen `.tres` files |
