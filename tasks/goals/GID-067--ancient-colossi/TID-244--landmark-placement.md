# TID-244: Landmark Placement — Deterministic Rarity Roll, Biome Variants, Chunk Integration

**Goal:** GID-067
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation task: decides which chunks host landmarks and which variant each gets, fully deterministically from world_seed. Meshes (TID-245) and discovery (TID-246) both consume this. Must be a pure function so the same world always has the same landmarks and headless tests can verify density without rendering anything.

## Research Notes

**Where generation lives:**
- `game_logic/world/InfiniteWorldGen.gd` builds each chunk in stages: tile grid → ruins (~33% of chunks) → entity spawning (entities appended as Dictionaries to `ChunkData.entities`; see the merchant spawn block as the pattern for a conditional, biome-aware entity).
- `game_logic/world/ChunkData.gd` holds `tile_grid: Array[int]` (256 entries, row-major `tz*16+tx`), `height_grid`, `entities: Array[Dictionary]`, `biome_id`.
- `IsoConst`: CHUNK_SIZE=16, TILE_SIZE=2.0, TILE_GRASS/TILE_HILL/TILE_WALL.

**Rarity roll:**
- ~1/60 chance per chunk, decided by a hash of (world_seed, cx, cz) — e.g. seed a local RandomNumberGenerator with `hash([world_seed, cx, cz])` or use an integer hash mod 60. Must NOT consume the chunk's main RNG stream in a way that shifts existing generation (ruins, enemies) — use an independent seeded RNG so existing worlds' terrain stays identical.
- Skip: chunks that rolled a ruin (avoid overlap clutter), and the safe zone near origin (see the safe-zone handling around `biome_for_chunk` / forced_start_biome in InfiniteWorldGen.gd — landmarks should still be findable but not on the spawn doorstep; skip radius ~3 chunks).

**Variant selection:**
- `biome_for_chunk(cx, cz, world_seed)` returns the regional biome (low-frequency simplex noise, BIOME_NOISE_FREQ=0.015). Map biome → variant pool, e.g.:
  - Grasslands → obelisk ring
  - Forest → overgrown stone head
  - Desert → kneeling colossus
  - Scorched → shattered spire
  - Mountains → broken stone bridge/arch
- 3–5 variants total is enough; one per biome is the simple mapping. Pick within-pool deterministically from the same hashed RNG.

**Chunk integration:**
- The landmark reserves a footprint (e.g. 5×5 tiles centred in the chunk): force those tiles to TILE_GRASS (flat, walkable approach) in the tile grid BEFORE the mesh/height stage so terrain doesn't poke through the structure.
- Append an entity Dictionary to `ChunkData.entities`, e.g. `{ "type": "landmark", "variant": "kneeling_colossus", "id": "landmark_<cx>_<cz>", "tx": 8, "tz": 8 }`. ChunkRenderer (TID-245) will instantiate from it; discovery (TID-246) keys persistence off the id.

**API suggestion:**
- `static func landmark_for_chunk(cx: int, cz: int, world_seed: int) -> Dictionary` (empty dict = none) in InfiniteWorldGen — callable by tests and by TID-246's name generator without building the whole chunk.

**Testing:**
- Headless test: scan e.g. a 100×100 chunk area for a fixed seed; assert density within a sane band (~1/40 to ~1/90), determinism across two scans, no landmarks in the safe zone, and variant matches the chunk's biome.
- GDScript strict mode: explicit types when RHS is `max`/`min`/`clamp`/untyped array index; typed arrays for `:=` on indexing.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
