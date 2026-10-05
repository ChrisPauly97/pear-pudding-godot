# TID-671: Worker Chunk Generation

**Goal:** GID-163
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-088 (archived). `_kick_chunk_jobs` ran `_ensure_tile_data_around` (up to 8 neighbour generations),
`snapshot_tile_grid_for` and `InfiniteWorldGen.generate_chunk` on the main thread.

## Research Notes (thread-safety audit)

- Lazy statics on the generation path: `InfiniteWorldGen._cached_noise` / `_biome_noise`, `TerrainMath`
  ley noises A/B, `EnemyRegistry._enemies` (`_ensure_loaded` sets `_loaded` *before* filling the table —
  a worker racing it would read an empty registry), `RealmLayout._maps` / `_plans` / `_streets` /
  `_entity_cache` / `_full_stamp_ctx`. All read-only once built.
- Pure / const: BiomeDef, StarterZone, RiftDefs, RiddleSpots, ChunkData, WorldMap reads of town maps.
- `WaterMath` (already worker-side via prepare_terrain) has its own mutex.
- Nothing reads a kicked chunk's *entity* data before commit: finders match chunk data against spawned
  nodes, which only exist after commit; unload uses the cache entry, inserted at commit.

## Plan

Kick → cache lookups only; worker generates and snapshots; commit inserts generated data where absent;
warm every lazy static at setup; verify by comparing streamed chunks to fresh main-thread generation.

## Changes Made

- `ChunkStreamingManager`: `_chunk_gen_task` (worker), static `_region_chunks` / `_copy_region`
  (shared by the main-thread `_snapshot_region` and the worker), new infinite-world kick, commit-side
  insert ("cache wins"), `InfiniteWorldGen.warm()` in `setup`. Named maps unchanged.
- `InfiniteWorldGen.warm(seed)`, `RealmLayout.warm()`.
- `tests/chunk_unload_smoke.gd`: every streamed chunk (102 built / 180 cached) must equal a fresh
  main-thread generation (tiles, heights, entity ids); a worker given the wrong seed fails it (116 diffs).
- Measured (12 u/s): main-thread kick 5-8 → 1-3 ms; p99 ~17 → 10.5-12 ms; max ~29 → 14-24 ms; 0 frames
  on an unbuilt chunk. `MAX_CHUNK_JOBS` 2 tried: lower max on 4 cores but more >8 ms frames — kept at 4.

## Documentation Updates

`docs/agent/world-generation.md` → Threading; CLAUDE.md TerrainMath section (purity + warm() rule).
