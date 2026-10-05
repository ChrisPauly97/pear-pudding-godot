# TID-673: WaterMath: early-out dry vertices, bucket dry points, bounded reserved distance

**Goal:** GID-164
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
