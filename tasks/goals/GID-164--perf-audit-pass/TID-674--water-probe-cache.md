# TID-674: Cache per-chunk dry points for water probes

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** TID-673

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`water_at_world` rebuilds chunk data per call and is hit dozens of times per 0.5 s. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/world/ChunkRenderer.gd:216-224` — `water_at_world` re-copies a 23×23 region (`snapshot_tile_grid_for`) and rescans (`_water_dry_points`) per call.
- Callers: `scenes/world/modules/AmbientTouches.gd:203-215` `_nearest_water` (up to 33 calls / 0.5 s) + `refresh()`; `scenes/world/modules/Critters.gd:91` `_walkable` per candidate.
- Fix: have `prepare_terrain` return `dry_points` (bucketed grid from TID-673); store per chunk key on the renderer / ChunkStreamingManager; erase on chunk unload. Named-map path needs the same cache or a lazily built one.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- Lazy per-chunk cache on ChunkStreamingManager (`_dry_cache`, `dry_grid_for(key, cd)`) instead of returning points from prepare_terrain: probes also hit chunks that never got a renderer, and one lazy build per chunk is the whole cost.
- Invalidate on data eviction, on commit/sync build of that key (entity points may change), and on `rebuild_terrain_around_tile` (3×3).

## Changes Made

- `scenes/world/ChunkStreamingManager.gd`: `_dry_cache`, `dry_grid_for()`, invalidation points.
- `scenes/world/ChunkRenderer.gd`: `water_at_world` uses the cache; `_water_dry_points` → public `water_dry_points`.
- `tests/unit/test_water_probe_cache.gd`: cached probe == fresh snapshot scan on a wet chunk; reuse asserted.
- Validation: import, gdlint, unsafe-hits, 3020 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/visual-polish.md` water clearance paragraph (probe cache).
