# TID-568: Stamp Towns & Roads into Chunk Generation

**Goal:** GID-138
**Type:** agent
**Status:** pending
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

## Changes Made

## Documentation Updates
