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

Lightweight container holding:
- `tile_grid: Array[int]` — 256 entries, row-major `[tz * 16 + tx]`
- `height_grid: Array[float]` — per-tile peak height (used by TerrainMath)
- `entities: Array[Dictionary]` — spawned enemies, chests, NPCs, doors

### Caching Strategy

- Chunks within load radius (6) are built and rendered
- Chunks beyond eviction radius (10) are removed from the cache
- The `_chunk_data_cache: Dictionary` in `WorldScene` maps `Vector2i(cx, cz)` → `ChunkData`
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

#### GameBus signals

| Signal | Payload | Description |
|---|---|---|
| `world_event_started` | `event_id: String` | Emitted when an event fires |
| `world_event_ended` | `event_id: String` | Emitted when `end_event()` is called |

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
| **WorldScene** | Orchestrator | Calls `InfiniteWorldGen.get_chunk(cx, cz)` and manages the cache and thread pool |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `InfiniteWorldGen.gd` | `game_logic/world/InfiniteWorldGen.gd` | Core generation script |
| `BiomeDef.gd` | `game_logic/world/BiomeDef.gd` | Biome parameter resource class |
| `ChunkData.gd` | `game_logic/world/ChunkData.gd` | Chunk container class |
| Terrain shaders | `assets/shaders/terrain.gdshader` | Receives per-biome tint uniforms from ChunkRenderer |
| Grass shaders | `assets/shaders/grass.gdshader` | Applied to grass tile layer |
| Terrain textures | `assets/textures/pixel_art/grass_pixel.png`, `hill_*.png`, `wall_*.png` | Sampled inside terrain shader |

No audio assets are currently required for world generation.
