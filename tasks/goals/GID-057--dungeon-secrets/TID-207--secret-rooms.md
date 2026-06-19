# TID-207: DungeonGen Secret Rooms — Seeded Hidden Room Generation

**Goal:** GID-057
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** claude/GID-057--dungeon-secrets
**Acquired:** 2026-06-19T00:00:00Z
**Expires:** 2026-06-19T00:30:00Z

## Context

Secret rooms are rare, deterministic chambers hidden behind cracked walls in dungeon corridors. Each dungeon seed determines whether it gets a secret room, where it is placed, and what chest it contains. The feature reuses existing entity placement logic (WorldMap chests) and introduces a new tile type to mark the breakable wall.

## Research Notes

- **DungeonGen.gd algorithm** (lines 29–175): Generate sequence is:
  1. Fill 80×60 tile grid with `TILE_WALL` (line 36–39)
  2. Generate 5 rooms left-to-right via `_gen_sequential_rooms()` (line 42) returning `Array[Rect2i]` in tile space
  3. Carve rooms via `_carve()` (line 44–45): set tiles to `TILE_GRASS`, heights to 0
  4. Connect adjacent rooms via `_connect()` (line 47–48): carve L-shaped 3-tile-wide corridors between room centres
  5. Assign room types (start, combat, rest, treasure, event) to middle rooms based on RNG rolls (line 64–78)
  6. Populate entities: enemies, NPCs, chests per room type (line 89–147)
  7. End room: chest + exit door (line 149–169)
  8. Save to `user://maps/dungeon_<name>.tres` (line 173)
  - **RNG seeding**: Single `RandomNumberGenerator` with `rng.seed = dungeon_seed` (line 30–31) drives all random choices (room positions, room types, enemy counts, card selection). **Deterministic per seed.**
  - **Tile indexing**: Flat tiles grid with `set_tile(tx, tz, value)` (WorldMap line 91–93). Boundaries: 0 ≤ tx < 100, 0 ≤ tz < 100.
  - **Entity placement**: Enemies at `world_pos = (tile_x * TILE_SIZE + 0.5, tile_z * TILE_SIZE + 0.5)` (DungeonGen line 106–107); chests same (line 131–132). IDs use prefixes: `"de_<num>"` (enemy), `"dtr_<num>"` (treasure room chest), `"dc_<num>"` (end chest).
  - **Chest entity structure** (line 129–135): `{"id": ..., "x": float, "z": float, "card_ids": [...], "opened": false}`

- **New tile type — TILE_CRACKED**: Add to **autoloads/IsoConst.gd** after TILE_PATH (line 22):
  ```gdscript
  const TILE_CRACKED: int = 4
  ```
  Currently IsoConst defines 0=GRASS, 1=WALL, 2=HILL, 3=PATH. TILE_CRACKED = 4 is the next integer.

- **Secret room insertion algorithm** (to add at end of DungeonGen.generate(), after line 78 room type assignment, before line 80 population):
  1. **Gate on 30% chance**: Roll `rng.randi() % 100 < 30` using the dungeon RNG
  2. If true:
     - **Pick insertion point**: Find a corridor tile (TILE_GRASS in a `_connect()` path). Simplest: after line 48, record corridor boundaries; or iterate all TILE_GRASS not in rooms post-carving, filter to corridors. Corridors are 3 tiles wide, at most DW long.
     - **Carve secret chamber**: Pick a wall tile adjacent to the corridor. Check that ≥3 tiles in each direction are TILE_WALL (to guarantee room interior won't hit map boundary or another room). Carve a 3×3 room of TILE_GRASS, heights 0.
     - **Place connecting tile as TILE_CRACKED**: The 1 tile connecting secret room to corridor becomes TILE_CRACKED (not TILE_GRASS). This is the breakable wall.
     - **Place chest**: Add one chest dict to `map.chests` (same structure as DungeonGen line 129–135, ID prefix `"dsr_<num>"` = dungeon secret room). Place at secret room centre, card_ids = 2 random from card_pool.
     - **Connectivity guarantee**: The secret room's only exit is through the TILE_CRACKED tile, so main-path connectivity is unaffected.

- **Renderer handling — TILE_CRACKED as wall variant**:
  - **TerrainMath** (docs/agent/terrain-rendering.md line 25–32, 38–41): `compute_height_field()` treats TILE_WALL and TILE_CRACKED identically for height computation — both contribute 0 height to the surface (walls are vertical).
  - **build_wall_mesh()** (docs/agent/terrain-rendering.md line 62–67): Emits one quad per exposed side of TILE_WALL. **TILE_CRACKED should also emit wall quads** (same as TILE_WALL). Modify the tile-type check in TerrainMath to `if tile == TILE_WALL or tile == TILE_CRACKED: ...`
  - **Texture variant**: Cracked walls use the same `wall_side_texture` and `wall_top_texture` at load time (simplest path for v1). Visual distinction happens at runtime via shader tint — later TID-208 applies a crack-pattern overlay or alternate texture.

- **Headless tests** (to add in `tests/runner.gd` or new test file):
  1. **Determinism**: Generate dungeon twice with same seed → secret room position + chest ID identical
  2. **Determinism (no secret)**: Generate dungeon with seed that rolls < 30% → no TILE_CRACKED tiles, chests list unchanged
  3. **Connectivity**: Flood-fill from spawn to exit without crossing TILE_CRACKED should succeed (main path unbroken)
  4. **Connectivity (secret unblocked)**: After secret room placed, flood-fill from secret room centre through TILE_CRACKED should reach corridor (secret accessible)
  5. **Chest placement**: Secret room chest has correct ID prefix and card_ids count

## Plan

1. Add `TILE_CRACKED = 4` to `autoloads/IsoConst.gd` and alias in `WorldMap.gd`.
2. Update `WorldMap.is_wall_at_world()` to treat TILE_CRACKED as a wall.
3. Update `TerrainMath.get_height_at()`, `compute_height_field()`, and `build_wall_face_mesh()` to handle TILE_CRACKED identically to TILE_WALL.
4. Update `ChunkRenderer._build_walls_physics()` to include TILE_CRACKED in wall collision.
5. Add `_try_gen_secret_room()` static to `DungeonGen.gd`; call it from `generate()` behind a 30% RNG gate.
6. Write tests in `tests/unit/test_dungeon_secrets.gd`.
7. Add to `tests/runner.gd`.

## Changes Made

- **autoloads/IsoConst.gd**: Added `const TILE_CRACKED: int = 4`.
- **game_logic/world/WorldMap.gd**: Added `TILE_CRACKED` alias; updated `is_wall_at_world()` to include it; added `find_chest_by_id()`; added `find_nearby_cracked_wall()`.
- **game_logic/TerrainMath.gd**: Extended tile type checks in `get_height_at()`, `compute_height_field()`, and `build_wall_face_mesh()` to treat TILE_CRACKED as a wall.
- **scenes/world/ChunkRenderer.gd**: Extended `_build_walls_physics()` wall detection to include TILE_CRACKED.
- **game_logic/world/DungeonGen.gd**: Added 30% secret room gate and `_try_gen_secret_room()` static method. Fixed bug: 3×3 carve was overwriting the TILE_CRACKED entrance tile — carve now runs before setting TILE_CRACKED.
- **tests/unit/test_dungeon_secrets.gd** + **.uid**: New test suite (10 tests; all pass).
- **tests/runner.gd**: Added `test_dungeon_secrets` preload.

## Documentation Updates

- `docs/agent/named-maps-and-dungeons.md` updated with TILE_CRACKED, secret room algorithm, and chest placement.
