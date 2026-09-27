# TID-568: Stamp Towns & Roads into Chunk Generation

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** TID-567

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`InfiniteWorldGen.generate_chunk` builds tiles from noise, then ruins, landmarks,
entities. Town footprints must override tiles/heights and suppress random content.

## Research Notes

- `InfiniteWorldGen._gen_tile_data / _gen_ruins / _gen_landmarks / _gen_entities`.
- Tile data comes from `MapData.tiles/heights` (row-major, width 100); read via the
  preloaded `.tres` consts in `MapRegistry` — needs a thread-safe accessor.
- Road tiles = `IsoConst.TILE_PATH`.

## Plan

`InfiniteWorldGen._stamp_realm()` after noise; suppress ruins/landmarks/chunk
scrolls/blight hearts in realm chunks; keep random spawns `REALM_CLEARANCE` tiles
off towns/roads; append stitched entities; force grasslands in town chunks; keep water out.

## Changes Made

- `InfiniteWorldGen`: `_stamp_realm`, `_append_realm_entities` (enemies, chests,
  doors, npcs, waystones), `REALM_CLEARANCE` filter on random spawns + mana wells,
  realm skip in `_gen_ruins` / `landmark_for_chunk` / `get_chunk_scroll_id`,
  `biome_for_chunk` → GRASSLANDS for town chunks.
- `BlightField.get_heart_for_super`: no heart in realm chunks.
- `WaterMath.intensity`: fades to dry within `REALM_DRY_TILES` of towns/roads.
- Tests: 2 chunk tests in `test_realm_layout`; `test_infinite_world_gen`,
  `test_landmark_system`, `test_water_math` now sample the wilds (chunk 0,0 is Madrian).

## Documentation Updates

- Deferred to TID-573.
