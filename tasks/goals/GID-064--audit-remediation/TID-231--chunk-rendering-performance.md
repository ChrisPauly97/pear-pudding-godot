# TID-231: Chunk streaming & rendering performance

**Goal:** GID-064
**Type:** agent
**Status:** pending
**Depends On:** TID-230

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The streaming pipeline does substantial avoidable work on the main thread and on the
mobile GPU, causing per-chunk hitches and a multi-second named-map load stall on
Android. Depends on TID-230 because both tasks restructure the same pipeline — land
correctness first.

## Research Notes

Ordered by expected impact:

1. **Grass buffers built on main thread (high).** `scenes/world/ChunkRenderer.gd:108` →
   `scenes/world/GrassBlades.gd:164-237, 239-274`: MultiMesh buffers (~16k-22k blades ×
   12 floats, per-instance RNG + trig, plus clusters) are built in GDScript at chunk
   commit time, while the terrain mesh is already threaded via `prepare_terrain`. This
   is the dominant per-commit cost. Fix: build the `PackedFloat32Array` inside
   `_chunk_prepare_task` (it touches no scene state) and only assign `mm.buffer` on the
   main thread.

2. **TerrainMath Callable hot path (medium).** `game_logic/TerrainMath.gd:94-113 (and
   32-51)`: the neighborhood scan calls the `tile_lookup` lambda up to 49×/vertex —
   33×33×49 ≈ 53k `Callable.call`s per chunk. Fix: add a packed-grid fast path (pass
   `PackedInt32Array` + origin/stride directly), keeping the Callable variant for the
   named-map `WorldMap.get_tile` path or converting that too via snapshot. Expected
   5-10× faster chunk prep. Keep TerrainMath the single source (CLAUDE.md rule).

3. **Main-thread tile gen per job (medium).** `scenes/world/WorldScene.gd:723-731`: per
   dispatched job the main thread runs `_ensure_tile_data_around` (up to 9×
   `generate_chunk_data_only` = 256 noise samples + ruins each) plus
   `_snapshot_tile_grid_for` (529 tiles × 2 dictionary lookups). Tile-only generation is
   pure/deterministic — move it into the worker task; keep only the cache insert on the
   main thread (guard the cache dictionary for thread safety — insert on commit).

4. **Named-map synchronous full build (medium).** `scenes/world/WorldScene.gd:222-228`:
   named maps build all ~49 chunks fully synchronously in `_ready`. Fix: sync-build only
   the chunks around the spawn and stream the rest through the existing threaded
   pipeline (named maps already produce ChunkData via `world_map.get_chunk_data`).

5. **Per-chunk material duplication (medium).** `scenes/world/ChunkRenderer.gd:98`:
   `terrain_mat.duplicate()` per chunk to set 3 biome tint uniforms — ~120+ unique
   ShaderMaterials (×2 mesh instances) for only 5 biome variants, defeating render-state
   sharing. Fix: cache 5 per-biome materials in a static Dictionary and share.

6. **Minimap re-renders the whole scene every frame (high, GPU).**
   `scenes/world/Minimap.gd:96`: the SubViewport uses `UPDATE_ALWAYS` with
   `own_world_3d = false` — the entire live 3D scene renders twice per frame on mobile.
   Fix: `UPDATE_DISABLED` + flip to `UPDATE_ONCE` every N frames from `Minimap.update()`,
   and set a `cull_mask` on `_mini_cam` to skip grass/detail layers.

7. **StoryScroll per-instance light + dead _process (low).**
   `scenes/world/entities/StoryScroll.gd:32-37, 45-49`: each scroll adds a real
   `OmniLight3D` although all world materials are unshaded (WorldItem.gd:64 comment
   confirms), paying clustering cost for zero visual result; `_process` computes a
   distance every frame into `_near_player` which is never read. Fix: emissive quad like
   WorldItem; delete `_process`.

Verification: time `_commit_chunk_results` and chunk prep before/after (print deltas in
a headless run); confirm named-map load no longer stalls; full test suite green.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
