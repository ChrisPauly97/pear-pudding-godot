# TID-673: WaterMath: early-out dry vertices, bucket dry points, bounded reserved distance

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Town chunk `prepare_terrain` costs 26 ms on the worker vs 13 ms wild; water fade math dominates. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `game_logic/world/WaterMath.gd:76-96` — `water_at` always runs `structure_fade` over every dry point even when intensity is 0. ~1089 verts × dry-point count; towns/roads have hundreds of PATH/WALL dry points.
- Called from `scenes/world/ChunkRenderer.gd:161-170, 190, 320`.
- `WaterMath.gd:68-70` → `RealmLayout.gd:168` `reserved_distance` loops all road segments, riddle spots, towns unfiltered; `TOWNS.keys()` / `world_rect()` allocate per call.
- Fix: compute intensity first, return early if <= 0; bucket dry points into a per-tile grid (check neighbouring cells only); pass the chunk's `stamp_context(cx, cz, true)` into a `reserved_distance_in(ctx, …)` or reuse the per-tile distance `_stamp_realm` computes (`InfiniteWorldGen.gd:223`) via ChunkData.
- Worker-thread path: must stay pure (CLAUDE.md TerrainMath/threading). Add equivalence test (old vs new output identical on sample chunks).

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- Early-out: `water_at`/`wet_at` skip the clearance scan on dry ground (and `wet_at` when intensity alone can't clear WET_LEVEL).
- `WaterMath.DryGrid`: dry points bucketed into 5-unit cells, lookup scans 3×3 (exact: farther points fade to 1).
- Realm skip: per-chunk proof (`reserved_distance` at the centre tile > REALM_DRY_TILES + 13; it is 1-Lipschitz) sets `realm_clear`, so `intensity` skips the town/road scan. Chosen over threading the stamp context through: one check per chunk, no signature churn.
- Equivalence test vs the old linear formula across town-adjacent and wild chunks, two seeds.

## Changes Made

- `game_logic/world/WaterMath.gd`: `DryGrid` inner class, `chunk_context()`, `intensity(..., realm_clear)`, `water_at`/`wet_at` take a `DryGrid` (null = no structures).
- `scenes/world/ChunkRenderer.gd`, `game_logic/world/TreeScatter.gd`: pass the `DryGrid`.
- `tests/unit/test_water_math.gd`: `test_chunk_context_matches_linear_scan`.
- Profile: town chunk prepare_terrain 27.6 → 16.6 ms, wild 17.3 → 12.7 ms.
- Validation: import, gdlint (all files), unsafe-hits, 3019 passed / 0 failed, 0 SCRIPT ERROR, all 44 smoke tests.

## Documentation Updates

- `docs/agent/visual-polish.md` water clearance paragraph.
