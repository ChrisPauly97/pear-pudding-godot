# TID-458: Packed-grid height field for chunk prep

**Goal:** GID-121
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`TerrainMath.compute_height_field` (game_logic/TerrainMath.gd:121) is the dominant
cost of `ChunkRenderer.prepare_terrain`: for each of 33×33 vertices it scans a 7×7
tile neighbourhood via `tile_lookup.call(...)` — ~53k dynamic lambda invocations per
chunk — even though the caller already holds the tile/height data as packed
`PackedInt32Array` grids (built by `ChunkStreamingManager.snapshot_tile_grid_for`).
This slows worker-thread chunk prep (late pop-in while walking) and, worse, runs
synchronously at startup: `build_initial_infinite` sync-builds 25 chunks and
`build_all_named_map` sync-builds every chunk of a named map through this exact
path — the Android load stall. Deferred from GID-064/TID-231 ("expected 5-10×
faster chunk prep").

## Research Notes

- Grid layout: `grid_min_x/grid_min_z` are global tile coords of grid cell (0,0),
  `grid_w` is both width and height (square). Out-of-range semantics in the
  ChunkRenderer lambdas: tile → `TILE_WALL`, height → `1`. Must be preserved.
- `TILE_CHECK = 3` (ChunkRenderer.gd:28) = `ceil(HILL_CURVE_R / TILE_SIZE) + 1`,
  so the 7×7 scan of any vertex inside the chunk always stays inside the snapshot
  grid — the out-of-range branch is defensive only.
- `build_terrain_mesh` / `build_wall_face_mesh` / `_compute_prop_positions` also take
  Callables but only make ~2-3k calls per chunk combined (~5% of the height-field
  count) — left on the Callable path deliberately to keep the diff small.
- CLAUDE.md: TerrainMath stays the single home of terrain algorithms — the fast path
  is a new static function *in TerrainMath*, not a copy elsewhere.

## Plan

1. Add `TerrainMath.compute_height_field_grid(tile_grid, height_grid, grid_min_x,
   grid_min_z, grid_w, origin_x, origin_z, nvx, nvz, step, curve_r, peak_h)` —
   identical algorithm/output to `compute_height_field`, but direct packed-array
   indexing in the inner loop (no Callable, no per-tile allocations).
2. Switch `ChunkRenderer.prepare_terrain` to it for the height field; keep the
   lambdas for the mesh builders and prop scatter.
3. Validate with gdparse; run headless compile check (blocked in sandbox — see goal).

## Changes Made

- `game_logic/TerrainMath.gd`: added `compute_height_field_grid()` — packed-grid
  fast path with identical output to `compute_height_field` (same neighbourhood
  scan, same wall-suppression rule, same out-of-range fallbacks TILE_WALL/1).
- `scenes/world/ChunkRenderer.gd`: `prepare_terrain` computes the height field via
  the packed fast path instead of per-tile lambda dispatch.

## Documentation Updates

- `docs/agent/terrain-rendering.md`: documented the packed-grid fast paths and when
  each variant (Callable vs packed) is used.
