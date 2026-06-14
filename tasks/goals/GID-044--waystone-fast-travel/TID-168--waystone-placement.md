# TID-168: Waystone Placement — Named Maps + Rare Seeded Infinite-Chunk Spawns

**Goal:** GID-044  
**Type:** agent  
**Status:** done  
**Depends On:** TID-167

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

Placing waystones in the world: one per town in named maps (via entity data), and seeded stochastic placement in infinite chunks (roughly 1 in 40 chunks on walkable tiles).

## Research Notes

- **Named-map waystone placement:**
  - Named maps are `.tres` resources in **`assets/maps/`** (see **`docs/agent/named-maps-and-dungeons.md`** lines 131–140 on adding built-in maps).
  - Bundled maps preloaded in **`autoloads/MapRegistry.gd`** lines 19–33: `_MAIN`, `_BLANCOGOV`, `_MADRIAN`, `_MAYKALENE`, `_FARSYTH_MANSION`, `_BLANCOGOV_TEMPLE` (6 total).
  - Entity loading flow: **`WorldMap.load_from_resource()`** (see **`game_logic/world/WorldMap.gd`**) iterates `MapData.waystones` (a new field added in TID-167), casts to `_MapWaystone`, converts tile coords to world coords, appends to `self.waystones`.
  - **Placement strategy:** Each town map should have exactly one waystone placed near the spawn (within ~5 tiles). Edit each `.tres` file in `assets/maps/` to add a `waystones` array entry OR use a map editor script to inject them.
  - **Friendly labels:** Add a `label: String` field to `MapWaystone` resource; for named maps, labels are the map name itself (e.g. "Main Town", "Blancogov", "Madrian").
  - **Preload tracking (Android):** See **`docs/human/CLAUDE.md`** "Map Storage" section — each `.tres` file needs a `.uid` sidecar. When you edit an existing `.tres`, the Godot editor updates the `.uid` automatically. If using a script to create new `.tres` files, generate a random 12-char UID sidecar (e.g. via `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`).

- **Infinite-world seeded placement:**
  - See **`docs/agent/world-generation.md`** lines 72–82 (ChunkData and caching strategy) and **`game_logic/world/InfiniteWorldGen.gd`** entity spawning flow.
  - Current entity spawn pattern: `InfiniteWorldGen.get_chunk(cx, cz)` returns a `ChunkData` containing a tile grid and an `entities` array. Entities (enemies, chests, NPCs) are spawned probabilistically per chunk using seeded RNG.
  - **Waystone probability:** Roughly 1 in 40 chunks (2.5%) on a random walkable tile. Hash chunk coords `(cx, cz)` with `world_seed` to derive a seeded RNG state (similar to how enemy/chest placement is seeded — check **`InfiniteWorldGen.gd`** for the exact hashing pattern).
  - **Tile selection:** Only place waystone on `TILE_GRASS` (not WALL/HILL). Use `ChunkData.tile_grid` (row-major `[tz * 16 + tx]`) to scan for walkable tiles; pick a random one if available.
  - **Waystone identity in infinite world:** Use absolute world tile coords: `"world:<world_tile_x>:<world_tile_z>"` (not chunk-local). Convert chunk coords to world via `world_x = cx * CHUNK_SIZE + tx_local`.
  - **Integration point:** Add waystone spawning to `InfiniteWorldGen._populate_entities()` or a separate `_spawn_waystones()` method called after enemies/chests/NPCs are added to `ChunkData.entities`.
  - **Friendly labels for world waystones:** Use a descriptive biome name or coordinates e.g. "Grasslands Waystone (128, 64)" or just "Waystone".

- **ChunkData entity dict structure:**
  - Existing entities in `ChunkData.entities` are dicts with `{type: String, x: float, z: float, ...}` fields (see how enemies are stored in chunk data).
  - Waystone entity dict: `{type: "waystone", x: float, z: float, id: String, label: String, active: false}`.
  - Same structure whether named-map or infinite-world.

- **WorldScene entity instantiation:**
  - In **`scenes/world/WorldScene.gd`** (where chests, doors, enemies are instantiated from entity dicts), iterate `world_map.waystones` and spawn Waystone scene instances.
  - Call `init_from_data()` on each waystone node after instantiation (like Chest and Door patterns).

- **Testing (deterministic chunk placement):**
  - Headless test: fixed world seed + fixed chunk coords should yield deterministic waystone presence (same chunk coords always have or don't have a waystone).
  - Test coverage: generate chunk (10, 5), check if waystone is in entities; regenerate same chunk, verify same waystone presence.

## Plan

1. Named maps: `.tres` files are large binary-text blobs that cannot be reliably edited by script without Godot editor parsing them. Instead, inject one waystone per named map in `WorldScene._spawn_named_map_waystones()` using a static ID/label dict — falls back to a procedural near-spawn placement when the `world_map.waystones` array is empty.
2. Infinite world: add waystone seeding at end of `InfiniteWorldGen._gen_entities()` using a separate `RandomNumberGenerator` seeded with `_chunk_seed(cx, cz, world_seed) + 7` — 1-in-40 probability, placed on a random grass tile from the collected `grass_tiles` list.

## Changes Made

- **`game_logic/world/InfiniteWorldGen.gd`**: Added waystone block at end of `_gen_entities()`. Uses `waystone_rng` (seed offset +7 from other placement RNGs) with 2.5% per-chunk probability. Picks a random grass tile and appends `{ id: "world:TX:TZ", x, z, label, active: false }` to `chunk.waystones`.
- **`scenes/world/WorldScene.gd`**: Added `_NAMED_MAP_WAYSTONE_LABELS` constant dict mapping map names to friendly labels. `_spawn_named_map_waystones()` uses `world_map.waystones` if populated; otherwise injects one waystone near the player spawn using the label dict. Covers all 6 bundled maps and arbitrary named maps.

## Documentation Updates

- Updated `docs/agent/waystone-fast-travel.md` with placement section.
