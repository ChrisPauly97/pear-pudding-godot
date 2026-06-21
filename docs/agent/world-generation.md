# World Generation

## Key Features

- Infinite, seamlessly streaming world divided into 16×16 tile chunks
- Five biomes: Grasslands, Forest, Desert, Scorched, Mountains — each with distinct terrain shape and enemy pools
- Simplex noise-based tile assignment (GRASS / HILL / WALL) with per-biome frequency and threshold tuning
- Height variation from 1 to 7 levels depending on biome steepness
- Procedural ruins generation (~33% of chunks) with variable size, walls, crumbled segments, and door openings
- Entity spawning per chunk: 0–2 enemies, 0–1 chest, 0–1 NPC
- Deterministic output: fixed world seed + biome seed ensures the same world each load
- Chunk data cached in memory; evicted when player moves far away

---

## How It Works

### Chunk Coordinates and Sizes

- `IsoConst.CHUNK_SIZE = 16` tiles per side
- `IsoConst.TILE_SIZE = 2.0` world units per tile
- Chunk world origin: `Vector3(cx * 16 * 2.0, 0, cz * 16 * 2.0)`

### Pipeline: `InfiniteWorldGen.gd`

Each chunk passes through three stages when first requested:

#### 1. Tile Grid Generation

```
For each tile (tx, tz) in 0..15 × 0..15:
  world_x = chunk_origin_x + tx
  world_z = chunk_origin_z + tz
  noise_val = simplex_noise.get_noise_2d(world_x * freq, world_z * freq)
  if noise_val > wall_threshold  → TILE_WALL
  elif noise_val > hill_threshold → TILE_HILL
  else                            → TILE_GRASS
```

Per-biome parameters in `BiomeDef`:
- `noise_frequency` — spatial scale; higher = more broken terrain
- `hill_threshold` — fraction of tiles that become hills
- `wall_threshold` — fraction that become walls (impassable)
- `max_height` — peak height for hill tiles (1–7)

The noise instance is seeded with `world_seed ^ biome_id` for determinism.

#### 2. Ruins Generation

With ~33% probability per chunk (seeded by chunk coordinates):

1. Pick random interior size: `inner_w` × `inner_h` (3–6 tiles each)
2. Place the ruin centred in the chunk
3. Write TILE_WALL border around the interior
4. Randomly crumble 20–40% of border wall tiles back to TILE_GRASS for visual variety
5. Punch 1–2 door openings in random border positions (each opening is 1 tile wide)
6. Insert a DOOR entity at each opening pointing to `dungeon_<chunk_seed>`

#### 3. Entity Spawning

After the tile grid is finalised:

- **Enemies (0–2):** Type selected by `EnemyRegistry.type_for_biome(biome, distance_from_origin)` — closer chunks use weaker enemy types, further chunks use stronger ones
- **Chests (0–1):** Random card reward; ~25% chance per chunk
- **NPCs (0–1):** ~25% chance; dialogue line selected from the biome's dialogue pool in `BiomeDef`
- Entities are placed only on TILE_GRASS tiles not already occupied

### BiomeDef (`game_logic/world/BiomeDef.gd`)

Defines each biome as a resource with:
- Noise parameters (frequency, thresholds, max height)
- Enemy pool: list of enemy type strings ordered by difficulty
- NPC dialogue: array of biome-flavoured one-liner strings
- Tint color for terrain shader (grass hue, hill hue, wall hue)

### ChunkData (`game_logic/world/ChunkData.gd`)

Lightweight RefCounted container holding:
- `tiles: PackedInt32Array` — 256 entries, row-major `[tz * 16 + tx]`
- `heights: PackedInt32Array` — per-tile peak height value (used by TerrainMath)
- `enemies`, `chests`, `doors`, `npcs`, `waystones`, `burial_mounds`, `landmarks`,
  `mana_wells` — `Array[Dictionary]` of spawned entity descriptors
- `biome_id: int`, `has_entities: bool`

### ChunkStreamingManager (`scenes/world/ChunkStreamingManager.gd`)

`Node3D` child added to WorldScene at `_ready()`. Owns all chunk lifecycle state and logic:

**State** (removed from WorldScene):
- `_chunk_data_cache: Dictionary` — `Vector2i(cx,cz)` → `ChunkData`
- `_chunk_renderers: Dictionary` — `Vector2i` → `ChunkRenderer` node
- Thread pool state: `_chunk_data_pending`, `_chunk_build_results`, `_chunk_build_mutex`,
  `_chunk_task_ids`, `_chunk_task_id_map`, `_chunk_build_queue`, `_chunk_queued`
- `_last_player_chunk`, `_last_move_dir`, `_last_dir_update_time`

**Public API:**
```gdscript
_csm.setup(world_seed, is_infinite, world_map, terrain_mat, world_scene)
_csm.build_initial_infinite(player_pos)      # infinite-world startup
_csm.build_all_named_map(max_cx, max_cz, player_pos)  # named-map startup
_csm.process_streaming(player_pos, player_vel, camera_frustum)  # per-frame tick
_csm.has_chunk_data(key: Vector2i) -> bool
_csm.get_chunk_data(key: Vector2i) -> RefCounted   # ChunkData or null
_csm.get_tile_global(wtx, wtz) -> int
_csm.get_height_global(wtx, wtz) -> int
_csm.get_last_player_chunk() -> Vector2i
_csm.get_last_move_dir() -> Vector2
_csm.rebuild_terrain_around_tile(tx, tz)
_csm.for_each_renderer(callback: Callable)   # iterates _chunk_renderers
_csm.exit_cleanup()                          # waits for WorkerThreadPool tasks
```

**Signals** (WorldScene connects to these):
```gdscript
signal player_chunk_changed(chunk: Vector2i, biome_id: int)
signal chunk_committed(key: Vector2i, chunk_data: RefCounted)
signal chunk_unloading(key: Vector2i, chunk_data: RefCounted)
```

### Caching Strategy

- Chunks within load radius (6) are built and rendered
- Chunks beyond eviction radius (10) are removed from the cache
- Cache managed entirely by `ChunkStreamingManager`
- Building runs on `WorkerThreadPool` (up to 4 concurrent tasks) to avoid frame stalls

---

## Living World Events

### WorldEventManager (`autoloads/WorldEventManager.gd`)

A lightweight scheduler that fires timed world events (roaming boss, traveling merchant,
card shower) while the player is in the infinite world. At most **one event is active at
a time** — the scheduler blocks further firing until the active event ends.

#### API

```gdscript
# Register a named event with a cooldown range (seconds).
WorldEventManager.register_event(
    "roaming_boss", 180.0, 360.0, spawn_callable, cleanup_callable)

# End the active event (called from the event's own logic, e.g. on defeat/despawn).
WorldEventManager.end_event("roaming_boss")

# Query state
WorldEventManager.is_event_active()         # → bool
WorldEventManager.get_active_event_id()     # → String

# Utility: find a walkable TILE_GRASS position between min_dist and max_dist
# world-units from player_pos. Pass the current save's world_seed.
var pos := WorldEventManager.find_spawn_tile(player_pos, 20.0, 50.0, world_seed)
```

#### Scheduling rules

- Timers only advance while `SceneManager.current_map == "main"` (infinite world) and
  outside battles (`enemy_engaged` / `battle_won` / `battle_lost` toggle `_in_battle`).
- Cooldown state is persisted in `SaveManager.world_events` (migration v17→v18) so
  cooldowns survive restarts. An event that was `active` at save time restarts its
  cooldown on load (v1; no mid-event respawn).
- Concrete events (TID-152 roaming boss, TID-153 merchant, TID-154 card shower) are
  registered from a `WorldEvents.gd` init script preloaded by WorldScene.

#### Registered events (`game_logic/WorldEvents.gd`)

| Event ID | Interval | Description |
|---|---|---|
| `roaming_boss` | 15–25 min | Spawns `roaming_terror` EnemyNPC at 1.5× scale with crimson materials 20–40 units away; minimap edge indicator; despawns on defeat or after 5 min or at >160 units |
| `traveling_merchant` | 10–20 min | Spawns violet `MerchantNPC` with `is_traveling=true` at 15–30 units away; 3 cards from 18-card premium pool at 30 coins each; no minimap marker; despawns after 5 min |
| `card_shower` | 8–15 min | Scatters 5–10 common WorldItem pickups at random walkable tiles 2–10 units from the player; one-shot yellow GPUParticles3D sparkle burst; plays `chest_open` SFX; items auto-despawn after 60 s; event ends when all items are collected or despawned |

#### GameBus signals

| Signal | Payload | Description |
|---|---|---|
| `world_event_started` | `event_id: String` | Emitted when an event fires |
| `world_event_ended` | `event_id: String` | Emitted when `end_event()` is called |
| `traveling_shop_requested` | `stock: Array[String], price: int` | Emitted by WorldScene on merchant interact; opens ShopScene with custom stock |

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **TerrainMath** | Used by | `ChunkRenderer` passes a lambda tile lookup into `TerrainMath.compute_height_field()` and `build_terrain_mesh()` |
| **ChunkRenderer** | Consumer | Receives completed `ChunkData` and builds all 3D meshes and entity nodes |
| **EnemyRegistry** | Data source | Biome + distance → enemy type string used during entity spawning |
| **SaveManager** | Seed source | `SaveManager.world_seed` seeds `InfiniteWorldGen`; `SaveManager.starting_biome` sets the safe-zone biome |
| **IsoConst** | Constants | `CHUNK_SIZE`, `TILE_SIZE`, tile type constants (`TILE_GRASS`, `TILE_HILL`, `TILE_WALL`) |
| **Named Maps / Dungeons** | Doors | Door entities generated inside ruins point to `dungeon_<seed>` named maps |
| **ChunkStreamingManager** | Orchestrator | Owns cache, thread pool, and all chunk lifecycle; child of WorldScene |
| **WorldScene** | Host | Creates CSM, connects its signals; delegates tile/height queries and streaming to CSM |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `InfiniteWorldGen.gd` | `game_logic/world/InfiniteWorldGen.gd` | Core generation script |
| `BiomeDef.gd` | `game_logic/world/BiomeDef.gd` | Biome parameter resource class |
| `ChunkData.gd` | `game_logic/world/ChunkData.gd` | Chunk container class |
| `ChunkStreamingManager.gd` | `scenes/world/ChunkStreamingManager.gd` | Chunk lifecycle orchestrator (extracted from WorldScene) |
| Terrain shaders | `assets/shaders/terrain.gdshader` | Receives per-biome tint uniforms from ChunkRenderer |
| Grass shaders | `assets/shaders/grass.gdshader` | Applied to grass tile layer |
| Terrain textures | `assets/textures/pixel_art/grass_pixel.png`, `hill_*.png`, `wall_*.png` | Sampled inside terrain shader |

No audio assets are currently required for world generation.
