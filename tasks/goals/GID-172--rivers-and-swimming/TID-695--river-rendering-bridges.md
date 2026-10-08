# TID-695: River rendering, banks & bridges

**Goal:** GID-172
**Type:** agent
**Status:** pending
**Depends On:** TID-694

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rivers need to look deep in the middle and be crossable on roads.

## Research Notes

- Water is drawn by the terrain shader from per-vertex UV2.y intensity baked in `ChunkRenderer` (see WaterMath header); sea uses 0.3 + 0.12/tile bands — reuse that depth banding for river depth. Water only renders on level grass, so river tiles must be flattened (hills fade like `RealmLayout` blend margin).
- Bridges where a river meets a road: plank/stone deck mesh built like `Coastline._build_piers` (SurfaceTool boxes), walkable (deep check must exclude bridge tiles, like `Coast.on_pier`).
- Bank props via `WaterMath.edge_prop` (reeds, lily pads in slow water, rocks in fast).
- `TapToMove.tile_at` (line ~249) currently walls `Coast.is_deep`; change deep river/sea to a high-cost swim tile — `Pathfinder.find_path` step_cost is 1/√2, add a cost multiplier per tile.
- `RealmMapOverlay` / minimap: draw river polylines.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
