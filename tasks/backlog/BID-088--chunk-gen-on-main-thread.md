# BID-088: Chunk data generation still runs on the main thread

**Category:** perf
**Discovered During:** GID-162 (measured with `tools/profile_world.gd`)

## Description

`ChunkStreamingManager._kick_chunk_jobs` generates the 3×3 neighbour tile data and the chunk's entity data
(`InfiniteWorldGen.generate_chunk`) on the main thread before handing only `prepare_terrain` to a worker.
After GID-162 a kick still costs ~5-8 ms near towns (town chunk ~3.5 ms warm), so chunk-boundary frames reach
~12-17 ms on a desktop core — several times that on phones.

## Suggested Resolution

Move data generation into the worker task (worker returns the generated ChunkData; commit inserts it into
`_chunk_data_cache` unless the main thread already filled it). Prerequisites for thread safety:
- Warm RealmLayout's lazy static caches (`_maps`, `_plans`, `_streets`, `_entity_cache`, `_full_stamp_ctx`) and
  InfiniteWorldGen's noise on the main thread at world start.
- Audit `EnemyRegistry.type_for_biome / is_tracking / get_deck` for lazy loading touched from a worker.
- Keep co-op determinism (same seed → same data) — generation is pure, so results are unchanged.
