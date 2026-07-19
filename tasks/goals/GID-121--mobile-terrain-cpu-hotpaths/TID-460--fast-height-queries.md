# TID-460: Fast per-frame terrain height queries

**Goal:** GID-121
**Type:** agent
**Status:** done
**Depends On:** TID-458

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`WorldScene.get_terrain_height` resolves through `TerrainMath.get_height_at` with
Callable tile lookups: ~49 `Callable.call`s per query, each landing in
`ChunkStreamingManager.get_tile_global` (float division + `Vector2i` alloc + two
Dictionary lookups + dynamic `chunk.get_tile()`), or `WorldMap.get_tile` (nested
Array indexing) on named maps. It is called every frame on the main thread by the
software floor in `WorldScene._process`, by `MaitelnFollower`, and by every
`RemotePlayer` avatar in co-op — plus at every entity spawn. On phone CPUs this is
~1-2 ms/frame in the worst cases, pure dispatch overhead.

## Research Notes

- Out-of-range fallbacks must match: infinite path never goes out of range (cache
  generates on demand); packed grids use tile→TILE_WALL, height→1, which is exactly
  `WorldMap`'s own out-of-bounds behaviour — so a grid covering the whole named map
  (100×100 + margin) gives identical results everywhere.
- Point queries scan tiles `vtx±3, vtz±3` (`tile_check = ceil(3.5/2)+1 = 3`), so a
  cached 3×3-chunk (48×48-tile) grid centred on the player's chunk safely answers any
  query within ±(16−3) tiles of the player chunk edges; everything else falls back to
  the existing Callable path (identical results, just slower — e.g. entity placement
  in far chunks during commit).
- Cache invalidation points: player chunk change (`_update_chunks`), tile edits
  (`rebuild_terrain_around_tile` — cracked-wall break, map editor).
- Reuses TID-459's `_snapshot_region` for the cache build (one block copy per chunk
  crossing, ~2,300 direct writes — amortised, off the per-frame path).

## Plan

1. Add `TerrainMath.get_height_at_grid(...)` — packed point query, same algorithm as
   `get_height_at`.
2. ChunkStreamingManager: maintain `_hq_*` cached grid (player chunk ±1 for infinite;
   whole map + TILE_CHECK margin for named maps, built once at setup), refresh on
   player chunk change and on `rebuild_terrain_around_tile`; add
   `get_height_world(wx, wz)` that uses the grid when the query neighbourhood fits
   and falls back to the Callable path otherwise.
3. Route `WorldScene.get_terrain_height` through `_csm.get_height_world` (keeping the
   old path when `_csm` is not yet set up).
4. Validate with gdparse; headless check blocked in sandbox (see goal).

## Changes Made

- `game_logic/TerrainMath.gd`: added `get_height_at_grid()` packed point query.
- `scenes/world/ChunkStreamingManager.gd`: added height-query grid cache
  (`_refresh_height_query_grid`), hooked into `setup` (named maps), `_update_chunks`
  (player chunk change), and `rebuild_terrain_around_tile` (tile edits); added
  `get_height_world()`.
- `scenes/world/WorldScene.gd`: `get_terrain_height` delegates to
  `_csm.get_height_world`, with the previous Callable path kept as pre-setup fallback.

## Documentation Updates

- `docs/agent/terrain-rendering.md`: height-query section updated (cached grid +
  fallback rules).
