# Named Maps and Dungeons

## Key Features

- Hand-authored or procedurally generated 100×100 tile maps stored as plain text files
- Text format encodes tile grid, sparse height overrides, player spawn, enemies, chests, NPCs, and doors
- Procedural dungeon generation via `DungeonGen` (seeded by door source)
- Map stack navigation: entering a door pushes the current map onto a stack; exiting pops back to the return door
- Maps load from `user://maps/` first (editable user saves), falling back to bundled `res://assets/maps/`
- Default generated map when the file is missing (border walls, interior obstacles, 8 enemies, 4 chests)

---

## How It Works

### Map File Format

Files live in `assets/maps/<map_name>.txt` (or `user://maps/<map_name>.txt`).

```
100 100                        ← width height (tiles)
0001100000...                  ← 100 rows of digit chars, no spaces
  0 = TILE_GRASS
  1 = TILE_WALL
  2 = TILE_HILL
HEIGHTS                        ← optional section header
3,7,2.5                        ← x,z,height  (sparse overrides)
SPAWN 5 5                      ← player start tile
ENEMY 12 8                     ← enemy at tile (12,8), default type
ENEMY 20 15 undead_horde       ← enemy with explicit type
CHEST 30 10 ghost skeleton     ← chest at (30,10) containing listed cards
NPC 5 20 The forest has eyes.  ← NPC with inline dialogue
DOOR 45 45 dungeon_a4f2        ← door leading to named map "dungeon_a4f2"
DOOR 10 10 main return_1       ← door to "main", targeting door id "return_1"
```

### Loading: `WorldMap.gd`

`WorldMap` is a `RefCounted` that parses the text file into:
- `tiles: Array[int]` — 10 000 entries, row-major `[z * 100 + x]`
- `heights: Dictionary` — sparse `"x,z" → float` overrides
- `entities: Array[Dictionary]` — one dict per ENEMY / CHEST / NPC / DOOR / SPAWN line

`get_tile(x, z)` returns `IsoConst.TILE_WALL` for out-of-bounds queries (safe default for mesh building).

### Saving Maps

`WorldMap.save(path)` serialises back to the same text format, enabling the in-game `MapEditorScene` to write edits to `user://maps/`.

### Dungeon Generation: `DungeonGen.gd`

When `SceneManager` is asked to enter a `dungeon_*` map name that has no existing file, it calls `DungeonGen.generate(seed_string)`:

1. Seeds an RNG from the string hash
2. Places a rectangular room grid (3–5 rooms wide, 3–5 tall)
3. Connects rooms with corridors (BSP / random walk)
4. Scatters walls inside rooms (~20% fill)
5. Places enemies by distance: easier types near the entrance, harder near the centre
6. Adds a return DOOR pointing back to the originating map/door id
7. Writes the result to `user://maps/dungeon_<seed>.txt` for persistence

### Map Stack Navigation

`SceneManager` maintains a `map_stack: Array[Dictionary]` in `SaveManager`:

```
enter_map(map_name, target_door_id):
  push { current_map, current_player_pos, return_door_id } onto stack
  load new WorldMap
  teleport player to the door tile matching target_door_id

exit_map_via_door(door):
  if stack is empty → do nothing (already at root)
  pop top entry
  restore previous WorldMap
  teleport player to the saved return_door_id tile
```

This supports arbitrary nesting depth (overworld → ruin dungeon → inner chamber → …).

### Default Map Generation

If neither `user://` nor `res://` contains the requested map file, `WorldMap._generate_default()` creates:
- Solid TILE_WALL border (1 tile thick)
- Random interior walls (~15% of tiles)
- 8 enemies of type `undead_basic`
- 4 chests with random common cards
- Player spawn at (5, 5)

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **WorldScene** | Consumer | Calls `WorldMap.load()` then passes `WorldMap.get_tile` as a `Callable` to `TerrainMath` for mesh building |
| **TerrainMath** | Mesh builder | Accepts `Callable` tile lookup from `WorldMap.get_tile`; builds height field + terrain mesh |
| **SceneManager** | Orchestrator | Owns the map stack; calls `enter_map()` / `exit_map_via_door()` on DOOR interaction |
| **SaveManager** | Persistence | `map_stack`, `current_map`, `player_x/z` are saved to `save.json` so navigation survives sessions |
| **InfiniteWorldGen** | Parallel path | For `"infinite"` mode, `WorldScene` uses `InfiniteWorldGen` instead of `WorldMap`; both feed the same `TerrainMath` API |
| **MapEditorScene** | Editor | Reads/writes `WorldMap` and saves to `user://maps/`; used for level design and debugging |
| **EnemyRegistry** | Entity typing | Enemy entities with explicit type strings are resolved via `EnemyRegistry.get_enemy(type)` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Bundled map files | `assets/maps/*.txt` | At least `main.txt` required as the starting overworld map. Building interiors (inns, houses) are embedded directly in their parent town map — no sub-map files. |
| `WorldMap.gd` | `game_logic/world/WorldMap.gd` | Loader/saver; exposes `get_tile(x,z)` Callable |
| `DungeonGen.gd` | `game_logic/world/DungeonGen.gd` | Procedural dungeon writer; only invoked if dungeon file absent |
| User maps directory | `user://maps/` | Created at runtime; stores edited + generated dungeon maps |
| Terrain textures | `assets/textures/pixel_art/` | Same textures used for both named maps and infinite chunks |
