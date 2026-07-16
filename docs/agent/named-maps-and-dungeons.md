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
| `MapNpc` | `game_logic/world/resources/MapNpc.gd` | NPC tile position + dialogue + npc_type + flag; `dialogue_group` for co-op |
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

**Door visual (GID-118):** every `MapDoor`-spawned entity (player home, guildhall,
shops, dungeon/ruin entries, the spire) renders as a billboard `Sprite3D` via
`SpriteRegistry.door_texture()` (0x72 pack door art), falling back to the
original flat-colored `BoxMesh` if missing. The spire door's purple tint is a
`Sprite3D.modulate` in sprite mode (a `Sprite3D` material swap in fallback
mode) — `Door.gd` stores `_is_spire` from `init_from_data()` (which always
runs before `_ready()`) and applies the tint once the visual actually exists
in `_ready()`. This also fixed a latent bug: the old code applied the spire
material inside `init_from_data()`, but `_ready()` ran afterward and
unconditionally overwrote it with the default brown material — so the spire
door's purple tint never actually rendered before this fix.

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
2. Fills 80×60 tile area with walls, carves 5 rooms, connects corridors.
3. Assigns room types (see Room Types below) and populates entities accordingly.
4. Calls `map.save_to_file(p_name)` → writes `user://maps/dungeon_<seed>.tres`.
5. Returns the WorldMap.

### Room Types

Each of the 5 dungeon rooms has a deterministic type derived from the seed:

| Room index | Type | Rule |
|---|---|---|
| 0 | start | Always safe; player spawn, no entities |
| 1 | combat | Always a fight (first guaranteed battle) |
| 2–3 | random | 60 % combat, 15 % rest, 15 % treasure, 10 % event |
| 4 | combat | End room: chest + exit door |

**combat** — 1–2 enemies (count + difficulty scales with depth).  
**rest** — NPC with `npc_type = "rest_site"`; pressing E opens the rest site panel (heal 8 HP or cull one card from deck). Room key stored in `npc["after_dialogue"]` as `<dungeon_name>_room_<idx>`.  
**treasure** — Chest id prefix `"dtr_"` with 2 random cards; no enemy. WorldScene opens at 40 % weapon drop chance (vs 15 % for standard chests).  
**event** — NPC with `npc_type = "event_room"`; pressing E loads a random event from `data/dungeon_events.json` (deterministic per room), shows text + 2-3 choices, applies outcome (coins, HP, cards).

### Secret Rooms (TILE_CRACKED)

After entity population, `DungeonGen.generate()` rolls a **30% chance** (seeded) to generate one secret room:

1. Scans all TILE_GRASS perimeter tiles for candidates — positions adjacent to a TILE_WALL tile where the 3×3 area two steps beyond the wall is entirely TILE_WALL.
2. Picks one candidate at random (seeded).
3. **Carves** a 3×3 TILE_GRASS room at the candidate location.
4. Sets the connecting wall tile to **`TILE_CRACKED`** (after the carve, to prevent the carve from overwriting it).
5. Adds a bonus chest with id prefix `"dsr_"` and 2 random cards at the room centre.

**`TILE_CRACKED = 4`** (defined in `autoloads/IsoConst.gd`). The tile:
- Renders as a wall face (same quads as TILE_WALL) **with a subtle brownish/dark tint** — cracked wall quads use vertex color alpha=0.3 (vs 1.0 for regular walls). The terrain shader reads `COLOR.a < 0.5 → v_cracked = 1.0` and applies `tinted_col = vec3(r*0.80+0.06, g*0.65, b*0.60)` to darken and warm-shift the wall color, making it visually distinct while remaining easy to miss.
- Blocks movement via `WorldMap.is_wall_at_world()` and `ChunkRenderer` box-collider merging.
- Does NOT break dungeon main-path connectivity — all rooms and the exit are accessible without passing through the cracked wall.

Secret room chest opens normally (no mimic roll).

**Break-open interaction**: `WorldScene._handle_interact()` checks `world_map.find_nearby_cracked_wall(px, pz, INTERACT_RANGE)` after the chest block. When a cracked wall is in range:
1. `world_map.set_tile(tx, tz, TILE_GRASS)` — converts the tile in memory.
2. `AudioManager.play_sfx("chest_open")` + `SceneManager.show_toast("Secret passage!", ...)`.
3. `_rebuild_terrain_around_tile(tx, tz)` — calls `ChunkRenderer.rebuild_terrain(snap)` on the tile's chunk and its 8 neighbours to update wall face meshes and physics colliders. Entity nodes in `entity_root` are untouched (only terrain children of ChunkRenderer are removed and rebuilt).
4. `world_map.save_to_file(current_map)` — persists the tile change to `user://maps/<dungeon>.tres`. On re-entry, the .tres is reloaded with TILE_GRASS in place of TILE_CRACKED, so the wall stays broken permanently for that save.

### Mimic Chests

Each dungeon chest (treasure room `"dtr_"` and end room `"dc_"`) has a **15% seeded chance** of being a mimic. The chest dict gains `"is_mimic": true`.

**Encounter flow:**
1. Player interacts with a mimic chest in `WorldScene._handle_interact()`.
2. `enemy_alert` SFX plays; toast "It's a Mimic!" shown.
3. `GameBus.enemy_engaged` emitted with `enemy_type: "mimic"`, chest `id` as enemy `id`.
4. Standard battle flow launches.

**Victory:**
- `SceneManager._on_battle_won()` detects `enemy_type == "mimic"`.
- Looks up the chest via `world_map.find_chest_by_id(chest_id)`.
- Grants chest `card_ids` to inventory at tier 3 rarity + one bonus card from mimic drop_pool.
- Adds `EnemyRegistry.get_coin_reward("mimic")` = 25 coins.
- Marks chest opened; records bestiary/bounty progress.

**Defeat:** Chest stays closed and `is_mimic` persists — the mimic is re-fightable on re-entry (determined by the dungeon's seeded `.tres` file).

**EnemyData**: `data/enemies/mimic.tres` — deck of 8 mixed basic cards, `difficulty_tier = 2`, `coin_reward = 25`. Registered in `EnemyRegistry` under `"mimic"` key.

**visited tracking**: `SaveManager.visited_dungeon_rooms: Array[String]` (persisted, version 9). `mark_dungeon_room_used(room_key)` / `is_dungeon_room_used(room_key)` — rest and event rooms can only be used once per save.

**Visual distinction on map overlay**: rest → teal dot (`_DOT_REST`), event → amber dot (`_DOT_EVENT`), treasure → yellow chest dot (existing), combat → red enemy dot (existing).

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

## Endless Spire Floors

Spire floors are small arena maps generated by `game_logic/spire/SpireFloorGen.gd`. They use the same named-map pipeline as dungeons but are always compact (12×8 cleared arena inside a 100×100 wall grid).

### Map naming

`spire_floor_<floor>_<run_seed>` — encodes both floor number and the run's seed so:
- Different runs generate different maps.
- Reopening the game after an app-kill reloads the same map (MapRegistry caches the `.tres`).

### WorldScene integration

`WorldScene._ready()` handles the `spire_floor_` prefix the same way as `dungeon_`:

```gdscript
elif map_name.begins_with("spire_floor_"):
    if MapRegistry.get_map(map_name) != null:
        world_map = WorldMap.new(map_name)   # reload from saved .tres
    else:
        var parts := map_name.split("_")
        world_map = SpireFloorGen.generate(int(parts[2]), int(parts[3]))
```

### Floor contents

| Entity | Position | Notes |
|---|---|---|
| Enemy | centre of arena | type and deck set by `SpireFloorGen.pick_enemy_type(floor)` |
| Exit door | east wall of arena | flag-gated; only unlocked after the enemy is defeated |

### Enemy ladder

| Floors | Enemy type | Boss? |
|---|---|---|
| 1–3 | `undead_basic` | no |
| 4–6 | `undead_horde` | no |
| 7–9 | `ghoul_pack` | floor 7 is boss |
| 10+ | `undead_elite` | every floor % 7 == 0 is boss |

### Exit door flow

The door has `flag_key = "spire_floor_<N>_<seed>_cleared"`. `SceneManager._on_battle_won()` sets this flag after a Spire battle win. The door becomes interactable only after the flag is set.

Interacting with the door calls `SceneManager.exit_map()`. If `is_spire_active()` and `current_map.begins_with("spire_floor_")`, `exit_map()` calls `_advance_spire_floor()` instead of popping the map stack — this loads `spire_floor_<N+1>_<seed>` as the new current map.

### Draft integration

Between defeating the enemy and walking to the exit door, `SceneManager._show_spire_draft(floor)` displays `SpireDraftScene` as a modal overlay. The player picks one card (added to `spire_run.draft_deck`), then the overlay closes, leaving the Spire floor world visible with the exit door now unlocked.

### Hero HP carry-over

`BattleScene._ready()` reads `spire_run.hero_hp` and applies it as the player hero's starting HP (clamped to max_health). After each battle `SceneManager._on_battle_won()` writes the final `hero_hp` back to `spire_run` via `save_manager.set_spire_hero_hp()`.

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
