# TID-266: Extract ChunkStreamingManager

**Goal:** GID-072
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
