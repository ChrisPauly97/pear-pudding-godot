# GID-121: Mobile Terrain CPU Hot Paths

## Objective

Eliminate the three biggest remaining CPU costs behind slow mobile performance — all
per-tile dynamic-dispatch (`Callable.call`) hot paths in the terrain pipeline.

## Context

User request: "find the top 3 reasons for slow mobile performance and fix them."

The GID-064 audit (TID-231) fixed the GPU-side offenders (grass main-thread build,
minimap re-render, material duplication) and explicitly deferred the CPU-side ones as
"higher risk of regression". Research for this goal re-confirmed they are still present
at HEAD and are now the dominant remaining costs (shadows are already off on mobile,
grass was cut ~5x by PR #359, DayNightCycle is throttled + cached, terrain shader is
branch-optimized):

1. **Chunk terrain prep runs ~53k `Callable.call`s per chunk**
   (`TerrainMath.compute_height_field` scans a 7×7 tile neighbourhood per vertex ×
   33×33 vertices through lambda lookups, even though `ChunkRenderer.prepare_terrain`
   already holds packed `PackedInt32Array` grids). Slows every streamed chunk on the
   worker thread (late pop-in, queue backlog) and runs synchronously at startup —
   25 chunks for infinite worlds, *every* chunk for named maps — causing the
   multi-second Android load stall. TID-231 estimated 5-10× improvement.

2. **Main-thread work per chunk kick**: `ChunkStreamingManager.snapshot_tile_grid_for`
   makes 529×2 `get_tile_global`/`get_height_global` calls (each: float division,
   `Vector2i` alloc, 2 Dictionary lookups, dynamic method call) per kicked chunk, up
   to 2 kicks per frame while walking — the chunk-boundary-crossing hitch.

3. **Per-frame terrain height queries** on the main thread go through the same
   Callable chain: `WorldScene._process` software floor (every frame), Maiteln
   follower, remote-player avatars, entity placement. Each `get_terrain_height` call
   is ~49 `Callable.call`s → ~150+ dynamic ops; on phone CPUs this is milliseconds
   per frame in co-op or while following.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-458 | Packed-grid height field for chunk prep | agent | done | — |
| TID-459 | Block-copy tile snapshot (kick path) | agent | done | TID-458 |
| TID-460 | Fast per-frame terrain height queries | agent | done | TID-458 |

## Acceptance Criteria

- [x] `compute_height_field` inner loop no longer performs one `Callable.call` per
      scanned tile on the chunk-prep path (packed-grid fast path, identical output).
- [x] `snapshot_tile_grid_for` no longer performs per-tile global lookups on the
      infinite-world path (per-chunk block copies).
- [x] Steady-state `get_terrain_height` calls resolve through direct packed-array
      indexing (cached player-area grid / named-map grid), with the Callable path
      kept as fallback so behaviour is unchanged at region edges.
- [x] TerrainMath remains the single source of terrain math (CLAUDE.md rule).
- [ ] Headless compile check + test suite green. **Note:** could not be executed in
      this sandbox — the network policy blocks the Godot binary download (GitHub
      releases + tuxfamily 403/reset). All edited files pass `gdparse` (gdtoolkit
      4.5.0) syntax validation. Run CI / local headless before merging.
