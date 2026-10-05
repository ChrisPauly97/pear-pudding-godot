# TID-674: Cache per-chunk dry points for water probes

**Goal:** GID-164
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
