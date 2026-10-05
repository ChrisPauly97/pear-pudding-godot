# TID-675: Direct packed-grid indexing in mesh/prop builders; per-town plan lookup

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** TID-673

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Callable tile lookups per vertex/tile are slow in GDScript; stamping refetches town plans per tile. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `game_logic/TerrainMath.gd:259` (`build_terrain_mesh` per-vertex `tile_lookup.call`), `:437-511` (`build_wall_face_mesh` ~6 calls/tile), `scenes/world/ChunkRenderer.gd:298` (prop/tree scatter).
- Precedent: `compute_height_field_grid` already takes packed `tile_grid`/`height_grid` + bounds.
- `RealmLayout.stamp_tile_in` (`RealmLayout.gd:278-283`) fetches `building_plan` / `street_plan` per in-town tile → resolve once per town inside the stamp context.
- Keep Callable signature for named-map path if needed (adapter), but both paths must share one algorithm (CLAUDE.md TerrainMath rule). Equivalence test mesh output.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- Measured `prepare_terrain` stage by stage first (temporary laps, reverted): height field ~9.2 ms, terrain mesh 1.4, ley/water 1.0, grass 0.8, trees 0.3, water-edge 0.3, props 0.2, wall faces 0.1. The Callable lookups the audit flagged live in the ~1.5 ms stages, so the real target was the height field.
- Height field: summed-area table of hill tiles; vertices with no hill in their 7×7 window stay 0 without the scan (exact — `_hill_blend` returns 0 when no hill is within curve_r).
- Callable → packed-grid in mesh/prop builders: **not done**, per measurement (≤1.5 ms on a worker thread, would duplicate the named-map path).
- `stamp_context` town entries now carry map, offset, building heights and street tiles, so `stamp_tile_in` does no per-tile plan fetch.

## Changes Made

- `game_logic/TerrainMath.gd`: `compute_height_field_grid` SAT skip.
- `game_logic/world/RealmLayout.gd`: `stamp_context` / `stamp_tile_in` per-town lookups resolved once.
- `scenes/world/ChunkRenderer.gd`: comment on the kept lambdas with the new measurement.
- `tests/unit/test_chunk_height_field.gd`: fast == full scan on 26 real chunks (hilly ones asserted); mutation-checked (window shrunk to 0 → fails).
- Profile: town chunk prepare_terrain 16.6 → 11.7 ms, wild 12.7 → 10.7 ms (baseline before GID-164: 27.6 / 17.3).
- Validation: import, gdlint, unsafe-hits, 3021 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/terrain-rendering.md` `compute_height_field_grid` row.
