# TID-277: Constants consolidation

**Goal:** GID-075
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
