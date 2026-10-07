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
| `MapNpc` | `game_logic/world/resources/MapNpc.gd` | NPC tile position + dialogue + npc_type + flag; `hide_flag_key` removes the NPC once that story flag is set; `dialogue_group` for co-op |
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
@export var shrines: Array[Resource] = []   # cast to MapPuzzleShrine at load time
@export var waystones: Array[Resource] = [] # cast to MapWaystone at load time
@export var triggers: Array[Resource] = []  # cast to MapTrigger at load time (future)
@export var regions: Array[Resource] = []   # cast to MapRegion at load time (future)
@export var music_track: String = ""
@export var difficulty: int = 0
@export var author: String = ""
@export var version: int = 1
```

Entity positions in `.tres` files are stored in **tile coordinates** (`tile_x`, `tile_z`). `WorldMap.load_from_resource()` converts these to **world coordinates** (`x = float(tile_x) * TILE_SIZE`) at load time.

**Hand-editing/generating `.tres` map files — a structural pitfall (GID-021,
BID-059):** every `key = value` line in Godot's `.tres` text format attaches
to whichever `[section]` header appeared most recently above it — a blank
line does **not** end a section, only the next `[...]` header does. If a
`MapData` scalar/array field (`scrolls`, `shrines`, `music_track`, etc.) is
written *after the last `[sub_resource]` block but before `[resource]`*,
it silently attaches to that last sub-resource instead of the top-level
`MapData` — and since that sub-resource's script doesn't declare the
property, Godot drops it on load with **no error, no warning**. This
exact bug shipped in 3 of the 5 story maps (BID-059) — `scrolls.size()`
and `shrines.size()` loaded as `0` despite the file clearly authoring
scroll/shrine sub-resources. **Always put every top-level `MapData` field
inside the final `[resource]` section**, never dangling before it. To
verify a map file loads what you think it does, `load()` it directly in a
throwaway headless script and inspect `.scrolls.size()` / `.shrines.size()`
/ etc. — a clean headless editor import does **not** catch this class of
bug, since misplaced-but-syntactically-valid properties parse without error.

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

Leaving the overworld pushes a `pos:x:z` token (not a door id) so the way back lands
the player where they went in; see "Stitched Story Realm" below.

---

## Stitched Story Realm (GID-138)

The five **outdoor** story towns — `madrian`, `maykalene`, `blancogov`, `larik`,
`marsax_hold` — are no longer entered by door. Their `.tres` files stay the
authoring source (the map editor still edits them), but at runtime each is cropped
and stamped into the infinite overworld (`main`) at a fixed tile offset, joined by
paved roads. The player walks between them with no transition. **Interiors**
(`blancogov_temple`, `farsyth_mansion`, `player_home`, `guildhall`, dungeons, spire)
are still door-entered named maps.

### `game_logic/world/RealmLayout.gd` (static, no autoloads)

| Table / helper | Purpose |
|---|---|
| `TOWNS[town] = {crop, offset, data}` | `crop`: part of the 100×100 source stamped (local tiles). `offset`: world tile = local tile + offset. `data`: preloaded MapData |
| `ROADS` | Polylines (world tiles) gate-to-gate; tiles within `ROAD_HALF_WIDTH` are `TILE_PATH` |
| `BLEND_MARGIN` | Hills fade flat over this many tiles around towns and roads |
| `OVERWORLD_TARGETS`, `DROPPED_DOORS` | Doors not stitched: town-to-town / to-overworld exits, and Madrian's debug shortcuts (`door_11`, `door_13`) into the mansion/temple |
| `STORY_SITES` | Fixed road tiles for the open-world story beats (`madrian_south_road`, `wilderness_camp`, `isfig_road`, `scout_ambush`) |
| `town_at_tile/world`, `world_rect`, `to_world_tile/pos`, `world_shift` | Coordinate helpers |
| `stamp_tile(wtx, wtz, noise_tile, noise_h)` | Town tile > road path > faded noise |
| `entities(kind)`, `entities_in_chunk(kind, cx, cz)` | Town entity dicts in world coords (cached; copies handed out). Generic `npc_N` ids become `<town>:npc_N` (every town has an `npc_1`); every other id is kept so save state carries over |
| `door_into(map)`, `return_pos_for(map)` | The stitched door into an interior; where you stand after leaving it |
| `pos_token(x, z)` / `parse_pos_token()` | `pos:x:z` tokens stored in `SceneManager.door_stack` |

Current layout (world = local + offset): madrian (−37,−33) — its spawn (local 30,30,
the town square) lands on world tile (−7,−3); maykalene (−37,66) south of it;
blancogov (43,222) south-east; larik (−167,232) west; marsax_hold (−167,100) north of Larik.
**Madrian layout (GID-165):** a compact village in crop (6,6)–(54,57): small houses
(5×5–9×7) around a paved square (local 25..35 × 24..32) with an animated stone
**fountain** at its centre (local 30,28), the shrine, bounty board and Maiteln; shopkeepers stand
**inside** their own building (inn, smithy, merchant, chandler, bakery, herbalist, chapel,
stable — GID-169) or yard (trainer, rift warden + Spire door, Old Tam
by the south road). Graveyard + sealed crypt in the south-west are unchanged. The
south road leaves at local (50,57). Indoor NPCs keep at least one tile off a building's
north and west walls (the back walls from the iso camera): a billboard beside them leans
into the wall and is clipped. No free-standing fence lines — keep walls to
building rings so NPCs never line up along a stray wall.

**The other towns follow the same rules (GID-170):** compact crops, small buildings round a
paved square with one TownDecor centrepiece, role NPCs indoors, every door signed.
- **Maykalene** crop (30,0)–(75,57): square 44..58 × 21..32, a grand three-tier marble fountain (51,27, radius 2, `grand_fountain`) sitting in a
  `pool` (octagonal marble basin of water drawn under the sprite by `StarterCamps._add_pool`); inn, Harbour Goods,
  archive, harbourmaster, cottages; cobbled street (x 50..52) south to the Farsyth Mansion, whose
  interior door sits in its north wall gap (51,46). East road leaves at local (75,40).
- **Blancogov** crop (28,2)–(73,57): golden gate tower pair at the north gate (road at 50,2) and two more
  pairs up the avenue (solid 3×3 towers, roof only); square 42..58 × 23..33 with the gilded statue
  (50,28); Duellists' Hall, Royal Library, The Golden Lyre; temple door in the avenue-end gap (50,45).
  West road leaves at local (28,50).
- **Larik** crop unchanged (33,35)–(65,63): six houses round a green with a well (48,48); Saimtar's
  empty house holds the letter (57,58).
- **Marsax Hold** crop (26,30)–(72,78): curtain-wall rampart with a south gatehouse gap on the road and
  a 3-tile west-wall breach (siege gate); keep, barracks, armoury, storehouse; courtyard brazier (50,60);
  war-camp door outside the breach (27,47).

**Town set pieces (GID-167, one per town since GID-170):** `game_logic/world/TownDecor.gd` `PIECES` (town → key,
local centre tile, blocked radius, world height). Each piece blocks a square of local
tiles: `TownStreets.plan(..., blocked)` never paves or routes through it (so TownLife
walkers go round), `TapToMove.tile_at()` reports it as a wall for A*, and
`StarterCamps._build_town_decor()` draws an `AnimatedSprite3D` (frames in
`_DECOR_FRAMES`, art from `tools/generate_fountain.py` / `tools/generate_town_pieces.py`) on a `StaticBody3D` cylinder on
the wall layer (4). Keep entities and the spawn off blocked tiles (`test_town_decor`).

**Building signs (GID-168):** `game_logic/world/TownSigns.gd` `signs(town)` puts one sign
per TownBuildings house with a door: one tile out from its first doorway and one to the
side (then two out), on grass/path clear of streets, set pieces, walls and entities. Name =
`NAMES[town][door gap tile]` (Madrian fully authored: inn, smithy, bakery…), else
`ROLE_NAMES` from an NPC with that `npc_type` in or by the building, else "House". The
`BuildingSigns` world module draws `town_sign.png` (`tools/generate_town_sign.py`) and
fades a Label3D name in while the player is within `POPUP_RANGE` (6 units) — no input, so
touch and desktop behave alike. A new house needs a `NAMES` row or it reads "House".

`test_realm_layout` checks towns don't overlap (incl. blend margin), roads end at towns,
sites sit on roads between towns, and doors/ids are stitched correctly.

### Runtime flow

- **Generation** (`InfiniteWorldGen`): `_stamp_realm()` after noise; ruins, landmarks,
  chunk scrolls, blight hearts skip realm chunks; random spawns keep `REALM_CLEARANCE`
  tiles off towns/roads; `_append_realm_entities()` adds enemies/chests/doors/NPCs/waystones;
  town chunks are always grasslands; `WaterMath.intensity` keeps towns/roads dry.
- **Props** (`NamedMapProps.spawn_realm()`): scrolls, shrines, injected `map:<town>`
  waystones and mailboxes, placed once on overworld load.
- **Region** (`scenes/world/modules/RealmRegions.gd`): per tile change, sets
  `WorldScene.current_town`; town entry sets the HUD name, music, entry toast, rivals,
  siege, `chapter1_reached_blancogov` / `chapter2_reached_larik`; leaving Madrian after
  the intro sets `chapter1_left_madrian`. **Use `WorldScene.story_place()`, not
  `map_name`,** for "is the player in town X" checks. `realm_regions.siege_gate(town)`
  shifts `SiegeDefs.TOWN_GATES` into the overworld.
- **Navigation** (`SceneManager`): new game → `enter_map("main")` (Madrian spawn);
  leaving the overworld pushes a `pos:` token so `exit_map` lands you where you went in;
  an interior with an empty stack steps out of its stitched door; `map:<town>` waystones
  teleport within the overworld (`_teleport_overworld`).
- **Saves**: v43 `SaveMigrations._m43_stitched_towns` moves a save in a stitched town to
  `main` at the shifted spot, collapses stitched stack entries into one `main` entry with a
  return token, and translates the player waypoint.
- **Co-op** still hosts on the named `madrian` map (BID-063).

### Town buildings (GID-154)

Town houses are authored as rings of 1-high wall tiles; the overworld raises them into buildings.

- `game_logic/world/TownBuildings.gd` (pure) — `detect(wm, crop)` returns `{heights, buildings}`.
  Rooms are found from their **floor**: open tiles are flood-filled with doorway gaps (a non-wall tile between two
  walls) treated as closed; every region that stays inside the crop and is ≤ `MAX_SPAN` (20) tiles a side, with
  ≥ 60 % wall on its border, is a `house` (`HOUSE_LEVELS` = 3). Its non-wall, non-corner border tiles are `doors`.
  A solid wall block ≥ 3×3 is a `tower` (4 levels). A wall component longer than `MAX_SPAN` (town walls) is a
  rampart (2 levels). Anything thinner than 3 tiles (fences) keeps its authored height.
- `RealmLayout.building_plan(town)` caches the plan; `stamp_tile` returns the raised height for those wall tiles, so
  `build_wall_face_mesh` and `_build_walls_physics` draw and collide with tall walls with no renderer change.
  `buildings_world()` gives every footprint in overworld tiles.
- `game_logic/world/BuildingMesh.gd` (pure) — `build_roof(b)`: surface 0 roof (gabled along the long axis, pitch
  `PITCH`, rise clamped `MIN_RISE..MAX_RISE`, `EAVE` overhang, shaded ridge cap; pyramid for towers), surface 1
  timber-framed gable ends, surface 2 brick chimney (houses ≥ 30 tiles). All UV-mapped in world units /
  `TEX_UNITS` (6.4 = the brick wall's ~20 px per unit); roof u runs along the ridge, v down the slope.
  `roof_style(rect)` picks one of `ROOF_STYLES` textures per footprint. `build_trim(b)`: wood lintels over door
  gaps, a painted door on the camera-facing (+Z) wall of closed houses, framed windows every `WINDOW_EVERY` border
  tiles (surface 0 wood, surface 1 emissive glass).
- Textures: `assets/textures/pixel_art/roof_{clay,slate,thatch,shingle,moss}_pixel.png` + `gable_pixel.png`,
  128×128 seamless, generated by `tools/generate_roof_textures.py` (imports keep `detect_3d/compress_to=0`, like
  the terrain tiles). Sampled nearest-neighbour.
- `scenes/world/TownBuildingsView.gd` (RefCounted, owned by `RealmRegions.buildings`, ticked from
  `RealmRegions.tick()`) builds every roof/trim on a WorkerThreadPool task kicked by the first overworld tick, committing
  the nodes on a later tick (GID-164 / TID-682). Roofs use one shared opaque material per texture (indexed by
  `roof_style`; gable and brick shared too) and take private transparent copies only while fading out (player's
  tile inside the footprint grown by 1; NPCs indoors stay visible) or back in. Each town's static trim (lintels,
  windows) is one merged mesh (`Trim_<town>`, wood + glass surfaces). Scenery only — not saved or synced.
- Interiors (door-entered named maps) and infinite-world ruins keep 1-high walls.

### Town streets and street lamps (GID-155)

Towns are authored as open grass; the overworld lays a street network over it and lines it with lamps.

- `game_logic/world/TownStreets.gd` (pure) — `plan(wm, crop, hub, gates, buildings)` returns
  `{tiles: {local Vector2i → true}, lamps: Array[Vector2i]}`. The hub is the town's player spawn (crop centre when
  the spawn is missing or outside the crop); gates are the `ROADS` endpoints that land within 2 tiles of the crop.
  Trunks run from each gate to the hub, `TRUNK_RADIUS` (1) tiles each side → 3 wide; lanes (1 wide) run from every
  house doorway gap and every door entity not inside a house to the nearest street already laid (nearest anchors
  first, so lanes share streets). Routing: BFS from the anchor over open tiles (grass / authored path, not inside a
  building's interior, inside the crop) until it touches the network, then a walk back that keeps its heading while
  that still descends, so streets come out straight. Routes over `MAX_ROUTE` (90) are dropped.
  Lamps: every `LAMP_SPACING` (7) steps along each route, alternating sides, `radius + 1` tiles off the centreline,
  on plain grass, ≥ `LAMP_MIN_GAP` (5) tiles from another lamp and never on or beside a door / NPC / chest / scroll /
  shrine / waystone / enemy tile.
- `RealmLayout.street_plan(town)` caches it; `stamp_tile` turns a planned **grass** tile into `TILE_PATH` (walls,
  hills and authored paths are left alone), so the terrain shader, minimap, map view, footsteps and pathfinding all
  treat streets like the realm roads. `street_lamps_world()` lists every lamp in overworld tiles.
- `game_logic/world/StreetLampMesh.gd` (pure) — one shared `ArrayMesh`: surface 0 soot-stained stone plinth,
  rust-flecked iron post, collars, lantern cage bars and pyramid cap (vertex-coloured grime); surface 1 the lantern
  glass (amber below, sooty at the top). `LIGHT_HEIGHT` (3.0) is the glass centre. Faces wind clockwise (Godot front).
- `scenes/world/TownStreetsView.gd` (RefCounted, `RealmRegions.streets`) — one `MultiMeshInstance3D` per town on the
  first overworld tick; `lamp_transform(t)` gives each lamp a stable yaw and a lean up to `MAX_LEAN` so rows look
  weathered. The glass uses `assets/shaders/street_lamp_glass.gdshader` (`EMISSION = COLOR * glow`, so the soot
  shows against the light); `tick()` eases `glow` between `GLOW_DAY` and `GLOW_NIGHT` from
  `night_lights.night_level()`. `lamp_positions()` feeds NightLights.
- **Light:** `NightLights` adds every street lamp as a `street_lamp` source (overworld only) — sooty amber, r 6.5,
  stronger flicker. Pooled rigs (Medium 4 / High 8 nearest) now always carry a real `OmniLight3D` (it lights walls,
  roofs and the lamp itself); it casts shadows only with `night_light_shadows`. Scenery only — not saved or synced.
- **Townsfolk (GID-156):** `RealmLayout.hub_of(town)` (the square: authored spawn, else crop centre) is shared by the
  street planner and `TownLife`, which walks plain townsfolk along these streets — see
  `docs/agent/enemies-and-npcs.md` → *Walking Townsfolk & Daily Schedules*.

### Adding / moving a stitched town

1. Add a `TOWNS` row (crop must include every entity you want stitched and the
   objective tiles in `ObjectiveTracker`; `test_town_objectives_sit_inside_their_stitched_town`).
2. Add a road from an existing town's edge to the new town's gate.
3. Doors to it from other towns go in `OVERWORLD_TARGETS`.
4. Run `test_realm_layout` / `test_objective_tracker`.

---

## Endless Spire Floors

> **GID-142:** the Spire is now per-biome **rifts** with tier ladders — see `docs/agent/rifts.md`. Sections below describe the original Endless Spire machinery the rifts are built on.

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

### Floor enemy ids

Each floor's enemy id comes from `SpireFloorGen.enemy_id_for(floor, run_seed)` → `"spire_enemy_<N>_<seed>"`. **It must stay unique per floor.** `SaveManager.defeated_enemies` is a permanent, map-agnostic list, so the shared literal `"spire_enemy"` this generator originally emitted meant clearing floor 1 marked every later floor's enemy defeated: `ChunkRenderer._spawn_entities` skipped the spawn, the arena came up empty, the cleared flag was never set, and the exit door (whose `flag_key` is that flag) stayed locked — a floor that could be neither won nor left. Anything keyed by enemy id (co-op defeat sync, bounty progress) had the same cross-floor bleed.

Use `SpireFloorGen.is_spire_enemy_id(eid)` rather than an equality check anywhere that routes or prunes by id — saves and `user://maps/` floors written before this change still carry the bare literal.

`SaveManager.spire.prepare_spire_floor(floor, run_seed)` runs from `WorldScene._load_named_map`'s spire branch, before the map is distributed into chunks: if the floor's cleared flag is unset the player still owes that fight, so every Spire kill is dropped from `defeated_enemies` to guarantee the spawn. This is also the repair path for saves already stuck on an empty floor. A cleared floor is left alone so standing on one you already beat doesn't resurrect it. `_clear_spire_enemy_defeats()` additionally runs at each run boundary (`start_spire_run`, `advance_spire_floor`, `end_spire_run`) so per-run ids never accumulate in the permanent list.

### Exit door flow

The door has `flag_key = "spire_floor_<N>_<seed>_cleared"`. `SceneManager._on_battle_won()` sets this flag after a Spire battle win. The door becomes interactable only after the flag is set.

Interacting with the door calls `SceneManager.exit_map()`. If `is_spire_active()` and `current_map.begins_with("spire_floor_")`, `exit_map()` calls `_advance_spire_floor()` instead of popping the map stack — this loads `spire_floor_<N+1>_<seed>` as the new current map.

The door is additionally held while `SceneManager.is_spire_draft_open()` — the draft overlay is a plain `Control` and doesn't pause world input, so the player can reach the door with a pick still owed. Advancing there would rebuild the scene and take the unclaimed card with it, so `exit_map()` emits a HUD nudge and returns instead.

### Draft integration

Between defeating the enemy and walking to the exit door, `SceneManager._show_spire_draft(floor)` displays `SpireDraftScene` as a modal overlay. The player picks one card (added to `spire_run.draft_deck`), then the overlay closes, leaving the Spire floor world visible with the exit door now unlocked.

**The draft must be shown from `_restore_world`'s post-swap callback, never inline after it.** `_restore_world(after: Callable)` defers its scene swap behind `TransitionManager`'s 0.2 s fade, so on the line after the call `get_tree().current_scene` is still the battle overlay that `_finish_battle()` just `queue_free()`d. Parenting the draft there makes it a child of a dying node and it is destroyed at the end of the frame — the floor clears, no draft ever appears, and the run continues on the same deck. `_spire_battle_won` therefore calls `_restore_world(_show_spire_draft.bind(curr_floor))`; the callback runs inside the transition, once `current_scene` is the live `WorldScene`. `tests/spire_draft_smoke.gd` drives the whole sequence with real frames and fails if the ordering regresses.

### Hero HP carry-over

`BattleScene._ready()` reads `spire_run.hero_hp` and applies it as the player hero's starting HP (clamped to max_health). After each battle `SceneManager._on_battle_won()` writes the final `hero_hp` back to `spire_run` via `save_manager.spire.set_spire_hero_hp()`.

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
| **AudioManager** | Music selection | `MapData.music_track` is threaded through `WorldMap.load_from_resource()`/`to_map_data()`; `WorldScene._named_map_music_track()` plays it when set, else `dungeon.ogg` for `dungeon_*`/`spire_floor_*` maps, else a peaceful default (`grasslands.ogg`) for hand-authored maps (BID-048) |

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
