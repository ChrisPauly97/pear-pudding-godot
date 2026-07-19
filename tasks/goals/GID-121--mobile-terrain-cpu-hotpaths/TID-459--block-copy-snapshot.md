# TID-459: Block-copy tile snapshot (kick path)

**Goal:** GID-121
**Type:** agent
**Status:** done
**Depends On:** TID-458

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Kicking a chunk job runs `ChunkStreamingManager.snapshot_tile_grid_for` on the main
thread: a 23×23 grid where every cell calls `get_tile_global` + `get_height_global` —
each doing a float division, `floori`, `Vector2i` allocation, two Dictionary lookups,
and a dynamic `chunk.get_tile()` call. That is ~1,060 dynamic-dispatch operations per
kick, up to 2 kicks per frame while the player crosses chunk boundaries — the
walking-hitch identified (and deferred) in GID-064/TID-231 item 3.

## Research Notes

- `ChunkData.tiles` / `ChunkData.heights` are `PackedInt32Array` in row-major
  `lz * CHUNK_SIZE + lx` layout (game_logic/world/ChunkData.gd) — block copies can
  read them directly with one Dictionary lookup *per chunk* instead of per tile.
- The 23×23 snapshot spans at most 3×3 chunks (TILE_CHECK=3 < CHUNK_SIZE=16).
- Missing cache entries must be generated exactly as `get_tile_global` does
  (`InfiniteWorldGen.generate_chunk_data_only` → cache insert), preserving identical
  results. `_ensure_tile_data_around` already pre-populates the 3×3 neighbourhood on
  the kick path.
- Named maps use `WorldMap.get_tile/get_height` (nested `Array[Array]` storage) and
  only snapshot at startup — a per-tile loop is kept there, but hoisted to avoid the
  double global-lookup dispatch.

## Plan

1. Add `_snapshot_region(min_tx, min_tz, w, h)` to ChunkStreamingManager: iterates
   the covered chunk blocks (infinite path), fetches each ChunkData once, block-copies
   rows out of its packed arrays; named-map path loops `WorldMap` accessors directly.
2. Rewrite `snapshot_tile_grid_for` on top of it (same return shape).
3. Validate with gdparse; headless check blocked in sandbox (see goal).

## Changes Made

- `scenes/world/ChunkStreamingManager.gd`: added `_snapshot_region()`; 
  `snapshot_tile_grid_for` now block-copies per chunk on the infinite path (one cache
  lookup per chunk instead of ~2 per tile, no Vector2i churn) and calls `WorldMap`
  accessors directly on the named-map path.

## Documentation Updates

- `docs/agent/terrain-rendering.md`: snapshot section updated (block copy).
