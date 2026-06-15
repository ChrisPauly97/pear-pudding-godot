# TID-230: Chunk streaming correctness

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Four verified correctness bugs in the chunk streaming / terrain pipeline, the worst of
which leaves **permanent holes in the world** at the spawn area.

## Research Notes

1. **Stale `_chunk_queued` flag (high).** `scenes/world/WorldScene.gd:214-220` pops the
   inner 5×5 chunks off `_chunk_build_queue` in `_ready()` and builds them via
   `_build_chunk_sync()` (:780-807), which never erases `_chunk_queued[key]`. Only
   `_kick_chunk_jobs` (:715/719/736) erases, and only for keys still in the queue; the
   unload loop (:594-629) doesn't touch it. After the player walks >UNLOAD_RADIUS away
   and returns, `_update_chunks()` (:562) skips those keys forever
   (`_chunk_queued.has(key)` → continue) — spawn-area chunks are never rebuilt.
   Fix: erase the flag in `_build_chunk_sync` (and audit chunk teardown for the same).

2. **WorkerThreadPool task IDs never reaped (medium).** `WorldScene.gd:737-739`
   appends `add_task` IDs to `_chunk_task_ids`, only waited in `_exit_tree` (:374-376).
   Godot requires `wait_for_task_completion()` to release each task; the array grows
   unboundedly. Fix: in `_commit_chunk_results`, call `wait_for_task_completion()` for
   completed IDs (cheap — already done) and remove them from the array.

3. **Hill ramp radius mismatch (medium).** Named maps render via
   `ChunkRenderer.prepare_terrain` with `CURVE_R = 3.5` (scenes/world/ChunkRenderer.gd:18),
   but `get_terrain_height()`'s named-map branch in `scenes/world/WorldScene.gd:510`
   uses `HILL_RAMP_R = 4.0`. Entities near hills float/sink ~0.1-0.2 units at mid-slope.
   Fix: use `ChunkRenderer.CURVE_R` in both branches (the infinite branch already does).

4. **Visibility range applied to first mesh only (medium).**
   `scenes/world/ChunkRenderer.gd:300-317` `_set_visibility_range()` sets
   `visibility_range_end = 50` on the first `MeshInstance3D` then returns. Enemy
   head/legs (EnemyNPC.gd:43-54), chest lock pip (Chest.gd:38-42), and Label3Ds are
   siblings added in `_ready()` — beyond 50 units the body disappears but heads/legs/
   labels keep rendering. Fix: iterate all `GeometryInstance3D` descendants (note the
   entity scripts add meshes in their own `_ready`, which runs after spawn — apply the
   range from the entity's `_ready` or defer the walk).

Also bundle these two latent/low items (same files):
- `scenes/world/ChunkRenderer.gd:50-54, 57-61` — snapshot-grid lookups guard only the
  flat index, not row bounds; an `ttx` one column outside wraps into the adjacent row.
  Currently unreachable (TILE_CHECK margins cover all callers) but bounds-check
  `ttx`/`ttz` against the grid rect.
- `game_logic/TerrainMath.gd:160-161 (and :26-27)` — `int((origin_x + x) / TILE_SIZE)`
  truncates toward zero instead of flooring; in the −X/−Z half of the infinite world,
  mid-tile vertices sample wall/path vertex-color flags from the wrong tile. Fix:
  `floori()`. (The `get_height_at` occurrence is absorbed by the +1 tile_check margin
  but fix both for consistency.)

Verified non-issues (don't re-investigate): unload-vs-cache-evict ordering is race-free
(UNLOAD_RADIUS 7 < CACHE_EVICT_RADIUS 10); HeightMapShape3D centering matches the mesh;
wall greedy-merge handles height changes.

Verification: headless script that builds chunks, simulates player moving out past
UNLOAD_RADIUS and back, asserts the chunk keys re-enter `_chunk_build_queue`. Run full
test suite.

## Plan

Fix all 4 verified bugs + 2 latent items in order. Bug 1: erase `_chunk_queued[key]` in `_build_chunk_sync`. Bug 2: add `_chunk_task_id_map` to reap completed WorkerThreadPool tasks. Bug 3: use `ChunkRenderer.CURVE_R` in named-map branch of `get_terrain_height`. Bug 4: iterate all `GeometryInstance3D` descendants in `_set_visibility_range`. Latent 5: explicit ttx/ttz bounds in snapshot lookups. Latent 6: `floori()` in TerrainMath for correct tile index in negative quadrant.

## Changes Made

- **`scenes/world/WorldScene.gd`**:
  - Added `var _chunk_task_id_map: Dictionary` (key→task_id).
  - `_build_chunk_sync()`: added `_chunk_queued.erase(key)` after registering renderer, so returning players can re-queue spawn-area chunks.
  - `_kick_chunk_jobs()`: stores `_chunk_task_id_map[key] = task_id` alongside existing `_chunk_task_ids.append`.
  - `_commit_chunk_results()`: calls `wait_for_task_completion(done_id)` and erases from both tracking structures when committing a result.
  - `get_terrain_height()`: named-map branch now uses `ChunkRenderer.CURVE_R` instead of `HILL_RAMP_R` (was 4.0, now 3.5 — matching the renderer).
- **`scenes/world/ChunkRenderer.gd`**:
  - `prepare_terrain()`: snapshot grid lookups now check `ttx`/`ttz` against column/row bounds before computing flat index, preventing cross-row wrap.
  - `_set_visibility_range()`: replaced first-match-then-return logic with `find_children("*", "GeometryInstance3D", true, false)` so all meshes (head, legs, labels) get the range.
- **`game_logic/TerrainMath.gd`**: Replaced 4 `int(x / TILE_SIZE)` → `floori(x / TILE_SIZE)` in `get_height_at`, `compute_height_field`, and `build_terrain_mesh` for correct tile index in the −X/−Z quadrant.

## Documentation Updates

None required.
