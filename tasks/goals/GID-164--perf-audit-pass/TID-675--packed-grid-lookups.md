# TID-675: Direct packed-grid indexing in mesh/prop builders; per-town plan lookup

**Goal:** GID-164
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
