# TID-694: River courses (pure logic)

**Goal:** GID-172
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rivers need a deterministic, chunk-independent course with depth so rendering, swimming and pathing all agree.

## Research Notes

- New `game_logic/world/Rivers.gd` (RefCounted, static). 2–3 seeded courses: start in Mountains-biome chunks (`InfiniteWorldGen.biome_for_chunk`, `BiomeDef.MOUNTAINS`=4), walk downhill/meander (low-freq noise) toward the eastern sea (`Coast.SHORE`, x≈43..262, z 43..146). Store as polylines of world tiles; built once in `InfiniteWorldGen.warm()`.
- API: `depth(wx, wz, seed)` signed tiles (>0 in river; deep core ≥ `Coast.WADE_DEPTH` 1.5), `flow(wx, wz)` downstream unit vector × speed, `width_at` growing downstream. Fords at crossings with `RealmLayout.ROADS` (road_distance) — shallow there; bridges are TID-695.
- Hook into `WaterMath.intensity`/`water_at`/`flow_at` (max with inland/sea water) so existing grass/props/splash code respects it; `RealmLayout.reserved_distance` so trees/ruins/spawns stay off rivers; rivers must not cut through stitched towns (`RealmLayout.town_at_tile`) — route around or stop.
- Per-query cost matters (WaterMath is hot in chunk prep): use a spatial bucket grid of segments, measure with `Time.get_ticks_usec()` (GID-164 lesson).
- Tests: determinism per seed, river reaches the sea, never enters a town, depth/flow continuity across chunk borders.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
