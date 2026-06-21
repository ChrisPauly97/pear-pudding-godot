# TID-266: Extract ChunkStreamingManager

**Goal:** GID-072
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chunk streaming orchestration is the biggest single cluster in WorldScene (~273 lines, 16% of the file) and is pure orchestration logic, independent of gameplay. This extraction removes a major responsibility and creates a reusable component for future infinite-world features.

## Research Notes

- **Lines to extract:** WorldScene.gd:536–808: `_update_chunks()` (load/unload radius, entity cleanup), `_kick_chunk_jobs()` (thread pool dispatch, sort queue), `_commit_chunk_results()` (scene-tree commit), `_build_chunk_sync()` (synchronous startup builds), `_ensure_tile_data_around()`, `_snapshot_tile_grid_for()`.
- **State dictionaries to move:** `_chunk_data_cache`, `_chunk_renderers`, `_chunk_queued`, `_pending_physics`.
- **Suggested new file:** `scenes/world/ChunkStreamingManager.gd`, owned by WorldScene, given Callables/references for player position and the renderer scene.
- **CLAUDE.md compliance:** Preload the new file (never rely on `class_name` for files created outside the editor).
- **COORDINATION ALERT:** GID-064 tasks TID-230 (chunk streaming correctness — terrain holes) and TID-231 (streaming performance) touch this exact code. If they are still pending, consider executing them as part of or right after this extraction; if done, re-verify line numbers and behavior before editing.

## Plan

Create `scenes/world/ChunkStreamingManager.gd` (+ `.uid` sidecar) and migrate all
chunk-lifecycle state and logic out of WorldScene into it.

### New file: ChunkStreamingManager.gd

Extends `Node3D`. Owns:

**State** (removed from WorldScene):
- `_chunk_data_cache`, `_chunk_renderers`, `_chunk_data_pending`, `_chunk_build_results`,
  `_chunk_build_mutex`, `_chunk_task_ids`, `_chunk_task_id_map`, `_chunk_queued`,
  `_chunk_queue_dirty`, `_pending_physics`, `_chunk_build_queue`, `_last_player_chunk`,
  `_last_move_dir`, `_last_dir_update_time`
- Constants: `LOAD_RADIUS`, `UNLOAD_RADIUS`, `CACHE_EVICT_RADIUS`, `MAX_CHUNK_JOBS`

**Config** (set via `setup()`):
- `_world_seed`, `_is_infinite`, `_world_map`, `_terrain_mat`, `_world_scene` (the WorldScene ref)

**Signals**:
- `player_chunk_changed(chunk: Vector2i, biome_id: int)` — WorldScene connects to update music/ambience/save
- `chunk_committed(key: Vector2i, chunk_data: RefCounted)` — WorldScene registers landmark data
- `chunk_unloading(key: Vector2i, chunk_data: RefCounted)` — WorldScene cleans up entity nodes/data

**Public methods**:
- `setup(world_seed, is_infinite, world_map, terrain_mat, world_scene)` — called from _ready
- `build_initial_infinite(player_pos)` — startup for infinite world (inner 5x5 sync, rest deferred)
- `build_all_named_map(max_cx, max_cz, player_pos)` — startup for named maps
- `process_streaming(player_pos, player_vel, camera_frustum)` — full per-frame tick (update/kick/commit/physics)
- `build_sync(key)` — exposed for named-map startup
- `get_last_player_chunk() -> Vector2i`
- `has_chunk_data(key) -> bool`
- `get_chunk_data(key) -> RefCounted`
- `get_tile_global(wtx, wtz) -> int`
- `get_height_global(wtx, wtz) -> int`
- `snapshot_tile_grid_for(key) -> Array` — public so WorldScene can call rebuild_terrain_around_tile
- `rebuild_terrain_around_tile(tx, tz)` — replaces WorldScene._rebuild_terrain_around_tile
- `for_each_renderer(callback: Callable)` — replaces direct `_chunk_renderers` iteration in _refresh_blight_tints
- `exit_cleanup()` — waits for in-flight thread tasks (called from WorldScene._exit_tree)

### WorldScene changes

1. Preload CSM and add `var _csm: ChunkStreamingManager = null`
2. `_ready()`: instantiate CSM, call `setup()`, connect signals, replace startup chunk calls
3. `_exit_tree()`: call `_csm.exit_cleanup()` instead of direct task wait loop
4. `_process()`: replace the big infinite-world streaming block with `_csm.process_streaming(...)`
5. `get_tile_global()` / `_get_height_global()`: delegate to `_csm.get_tile_global()` / `_csm.get_height_global()`
6. `_rebuild_terrain_around_tile()`: delegate to `_csm.rebuild_terrain_around_tile()`
7. `_refresh_blight_tints()`: use `_csm.for_each_renderer()`
8. `_find_walkable_spawn_tile()`, `_find_nearby_enemy()`, `_find_nearby_chest()`: use `_csm.has_chunk_data()` / `_csm.get_chunk_data()`
9. Remove extracted state vars, constants, and functions
10. Connect `chunk_unloading` signal to a new `_on_chunk_unloading(key, chunk_data)` method that cleans up entity nodes; connect `chunk_committed` to populate `_active_landmark_data`

Note: `register_chest/door/npc/waystone/burial_mound/mana_well` callbacks stay on WorldScene since
ChunkRenderer calls them via duck typing on the `world_scene` arg. The explicit active-data
population loops inside `_commit_chunk_results()` / `_build_chunk_sync()` are removed — those
dicts are populated via the register_ callbacks instead.

## Changes Made

- **Created** `scenes/world/ChunkStreamingManager.gd` (~340 lines): `Node3D` that owns all
  chunk-lifecycle state (`_chunk_data_cache`, `_chunk_renderers`, `_chunk_data_pending`,
  `_chunk_build_results`, `_chunk_build_mutex`, `_chunk_task_ids`, `_chunk_task_id_map`,
  `_chunk_queued`, `_chunk_queue_dirty`, `_pending_physics`, `_chunk_build_queue`,
  `_last_player_chunk`, `_last_move_dir`, `_last_dir_update_time`) and all associated logic
  (`_update_chunks`, `_kick_chunk_jobs`, `_commit_chunk_results`, `_build_chunk_sync`,
  `_ensure_tile_data_around`, `snapshot_tile_grid_for`, `_chunk_in_frustum`,
  `_chunk_prepare_task`, `exit_cleanup`).
- **Created** `scenes/world/ChunkStreamingManager.gd.uid` sidecar.
- **Signals** on CSM: `player_chunk_changed(chunk, biome_id)`, `chunk_committed(key, chunk_data)`,
  `chunk_unloading(key, chunk_data)`.
- **Added** `get_last_move_dir() -> Vector2` getter to CSM (used by WorldScene ghost phase cantrip).
- **WorldScene.gd**: removed ~400 lines of extracted code; replaced with single `_csm` reference.
  Added `_on_player_chunk_changed`, `_on_chunk_committed`, `_on_chunk_unloading` signal handlers.
  Delegated `get_tile_global`, `_get_height_global`, `_rebuild_terrain_around_tile`,
  `_refresh_blight_tints`, `_find_nearby_enemy`, `_find_nearby_chest`, nocturnal spawn tile checks.
- **Bug fix**: corrected `chunk.tile_grid` → `chunk.tiles` in nocturnal spawn walkable tile check
  (pre-existing incorrect property name).

## Documentation Updates

- Updated `docs/agent/world-generation.md`: added ChunkStreamingManager section describing
  ownership, signals, public API, and integration with WorldScene.
