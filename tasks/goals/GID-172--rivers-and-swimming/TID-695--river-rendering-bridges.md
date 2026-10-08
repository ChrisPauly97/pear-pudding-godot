# TID-695: River rendering, banks & bridges

**Goal:** GID-172
**Type:** agent
**Status:** done
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

1. `Rivers`: bridges at every ford (oriented rect along the road), `on_bridge`, `deep_water` (sea or river, minus bridges/piers), `road_tile` (river bed under a bridge stays water), `nearest_dry` (wade-ashore search).
2. `RealmLayout.stamp_tile_in`: road tiles use `Rivers.road_tile` (line-neutral; file at its 500-line cap).
3. `scenes/world/RiverBridges.gd` static builder; `Coastline` builds the bridges and blocks deep river water too (WorldScene is at its line ceiling, so no new module). TapToMove walls deep river water.
4. `WaterMath.edge_prop` "river_rock" in fast water; ChunkRenderer + SpriteRegistry keys.
5. `RealmMapOverlay` draws the rivers.
6. Tests: bridge deck/stamp/orientation, deep water + wading ashore, rocks; realm stamp test follows the bridge rule.
Depth shading needs no shader change: the river's intensity already uses the sea's depth bands.

## Changes Made

- `game_logic/world/Rivers.gd`: `bridges()`, `on_bridge`, `deep_water`, `road_tile`, `nearest_dry` (+ `_ring`).
- `RealmLayout.stamp_tile_in`: paved road → `Rivers.road_tile` (grass under a bridge over water).
- New `scenes/world/RiverBridges.gd` (`make_bridge`: slab deck, capped parapets, pillars). `Coastline` builds one per bridge,
  slides the hero out of deep river water too and wades ashore via `Rivers.nearest_dry`.
- `TapToMove.tile_at`: `Rivers.deep_water` is a wall (sea or river).
- `WaterMath.edge_prop` → `"river_rock"`; `ChunkRenderer._compute_water_edge_props` places them at the water surface; `SpriteRegistry` `river_rock` variants.
- `RealmMapOverlay._draw_rivers` (later dropped in the merge with the painted realm map, which draws rivers from `WaterMath.sea_at`).
- Tests: `test_rivers` +3 (bridge, deep water/wading ashore, rocks); `test_realm_layout` stamp rule follows `Rivers.road_tile`.
  Suite 3063 pass / 0 SCRIPT ERROR; world + chunk smokes clean; gdlint + unsafe-hits clean.
- Not verified visually (headless only): bridge look and rock placement should be eyeballed in a real run.

## Documentation Updates

`docs/agent/world-generation.md` (Rivers: bridges, deep water, banks); CLAUDE.md Coastline module row.
