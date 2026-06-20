# TID-277: Constants consolidation

**Goal:** GID-075
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

CHUNK_SIZE is redefined in 7 places and terrain-shape constants diverge between the two rendering paths, violating the IsoConst single-source rule (CLAUDE.md "Canonical Constants" section). This creates maintenance risk and potential inconsistencies in terrain geometry between named maps and infinite chunks.

## Research Notes

### CHUNK_SIZE duplicates
- **Canonical:** `IsoConst.gd:4`
- **Duplicates:** `ChunkRenderer.gd` (~lines 42/158/201 — verify, may be local consts or magic numbers), `GrassBlades.gd:58`, `WorldScene.gd:224` and `660`, `InfiniteWorldGen.gd:7`, `WorldMap.gd:603`, `ChunkData.gd:3`
- **Fix:** Replace all with `IsoConst.CHUNK_SIZE`

### TILE_SIZE mismatch
- **Canonical:** `IsoConst.TILE_SIZE` (correct usage in `DungeonGen.gd:19` and `WorldMap.gd:20`)
- **Incorrect:** `InfiniteWorldGen.gd:8` hardcodes `2.0` instead of `IsoConst.TILE_SIZE`
- **Fix:** Replace with `IsoConst.TILE_SIZE`
- **Note:** WorldMap's aliases are sanctioned backward-compat per CLAUDE.md, leave them

### Terrain-shape mismatch (REAL INCONSISTENCY)
- **Named maps** (WorldScene.gd:136–138):
  - `HILL_PEAK_H = 1.5`
  - `HILL_RAMP_R = 4.0`
  - `TERRAIN_VDENSITY = 2`
- **Infinite chunks** (ChunkRenderer.gd:16–19):
  - `PLATEAU_H = 1.5`
  - `CURVE_R = 3.5`
  - `TERRAIN_VDENSITY = 2`
- **Issue:** Ramp radius differs (4.0 vs 3.5), so hill slopes differ between named maps and the open world.
- **Decision required:** Either intentional per-path tuning (then centralize both as named constants in IsoConst or TerrainMath with a comment stating they intentionally differ) or unify to one value (visually verify hills on a named map AND in the open world before/after — see /verify or run skill if usable, else reason from TerrainMath.compute_height_field usage). Default recommendation: centralize, keep values as-is, document — changing terrain shape silently is riskier than the duplication.

### Other constants
- **MAP_WIDTH/MAP_HEIGHT = 100** live only in `WorldMap.gd:18–19` — fine where they are (named-map specific)
- **ENTITY_VISIBILITY_END** (ChunkRenderer.gd:298) — move to IsoConst while in there

## Plan

1. Add `HILL_PEAK_H`, `HILL_CURVE_R`, `TERRAIN_VDENSITY`, `ENTITY_VISIBILITY_END` to `IsoConst.gd`.
2. Remove local duplicates from `ChunkRenderer.gd` (class-level `TERRAIN_VDENSITY`, `PLATEAU_H`, `CURVE_R`, `ENTITY_VISIBILITY_END`; 2 local `const CHUNK_SIZE` inside functions).
3. Remove `HILL_PEAK_H`, `HILL_RAMP_R` (dead — never fed into terrain compute), `TERRAIN_VDENSITY` (dead) from `WorldScene.gd`; update usages to `IsoConst.*`.
4. Remove class-level `CHUNK_SIZE` from `ChunkData.gd` and `InfiniteWorldGen.gd`; replace all usages with `IsoConst.CHUNK_SIZE`. Remove `TILE_SIZE` from `InfiniteWorldGen.gd`; use `IsoConst.TILE_SIZE`.
5. Remove local `const CHUNK_SIZE` in `GrassBlades.gd` (1 class-level + 2 function-level) and `WorldMap.gd` (1 function-level); update usages.
6. Update test files that referenced `ChunkData.CHUNK_SIZE` to use `IsoConst.CHUNK_SIZE`.

## Changes Made

- **MODIFIED `autoloads/IsoConst.gd`**: Added 4 new canonical constants: `HILL_PEAK_H = 1.5`, `HILL_CURVE_R = 3.5`, `TERRAIN_VDENSITY = 2`, `ENTITY_VISIBILITY_END = 50.0` with doc comment explaining both rendering paths share them.
- **MODIFIED `scenes/world/ChunkRenderer.gd`**: Removed `TERRAIN_VDENSITY`, `PLATEAU_H`, `CURVE_R`, `ENTITY_VISIBILITY_END` class-level consts. Removed 2 local `const CHUNK_SIZE: int = 16` inside `_build_geometry_worker()` and `_build_wall_collision()`. All replaced with `IsoConst.*` references.
- **MODIFIED `scenes/world/WorldScene.gd`**: Removed 3 dead/duplicated consts `HILL_PEAK_H`, `HILL_RAMP_R`, `TERRAIN_VDENSITY`. Removed 2 local `const CHUNK_SIZE: int = 16` inside `_setup_world()` and `_snapshot_tile_grid_for()`. Updated `compute_height_field` calls to use `IsoConst.HILL_CURVE_R` and `IsoConst.HILL_PEAK_H`.
- **MODIFIED `scenes/world/GrassBlades.gd`**: Removed 1 class-level `const CHUNK_SIZE := 16` and 2 function-level `const CHUNK_SIZE: int = 16`. All replaced with `IsoConst.CHUNK_SIZE`.
- **MODIFIED `game_logic/world/ChunkData.gd`**: Removed `const CHUNK_SIZE: int = 16` class-level const. All 14 usages replaced with `IsoConst.CHUNK_SIZE`.
- **MODIFIED `game_logic/world/InfiniteWorldGen.gd`**: Removed `const CHUNK_SIZE: int = 16` and `const TILE_SIZE: float = 2.0`. All usages replaced with `IsoConst.CHUNK_SIZE` and `IsoConst.TILE_SIZE`.
- **MODIFIED `game_logic/world/WorldMap.gd`**: Removed 1 local `const CHUNK_SIZE: int = 16` inside `get_chunk_data()`. Replaced with `IsoConst.CHUNK_SIZE`.
- **MODIFIED `tests/unit/test_chunk_data.gd`**: Updated 8 references from `ChunkData.CHUNK_SIZE` to `IsoConst.CHUNK_SIZE`.
- **MODIFIED `tests/unit/test_infinite_world_gen.gd`**: Updated 4 references from `ChunkData.CHUNK_SIZE` to `IsoConst.CHUNK_SIZE`.
- **MODIFIED `tests/unit/test_named_map_npcs.gd`**: Removed local `const CHUNK_SIZE: int = 16`; replaced 4 usages with `IsoConst.CHUNK_SIZE`.
- **NOTE on terrain radius**: `WorldScene.HILL_RAMP_R = 4.0` was dead — WorldScene already used `ChunkRenderer.CURVE_R = 3.5` (now `IsoConst.HILL_CURVE_R`) for actual terrain computation. Both paths now consistently use 3.5.

## Documentation Updates

Updated `docs/agent/signals-and-constants.md` — added the 4 new IsoConst terrain constants to the constants table.
