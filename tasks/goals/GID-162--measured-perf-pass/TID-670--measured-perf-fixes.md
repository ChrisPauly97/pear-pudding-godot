# TID-670: Measured Perf Fixes

**Goal:** GID-162
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal. Run: `godot --headless --path . -s tools/profile_world.gd [-- --speed 12 --frames 900 --orphans]`.

## Research Notes (measurements)

- Spikes sat on chunk-boundary crossings in frames that **kicked** chunk jobs: the kick's main-thread prep
  (3×3 neighbour tile gen + entity gen) cost 8-12 ms per chunk near the realm.
- `generate_chunk_data_only` for a chunk touching a road / town margin: **5.95 ms** — `RealmLayout.stamp_tile`
  rescanned every town rect, road segment and legend spot for each of 256 tiles.
- Town chunk `generate_chunk`: 4.3 ms warm (14 ms cold, one-off town plans).
- `QuestTracker.refresh` (every 250 ms): **0.85-1.5 ms**, ~all in `_refresh_npc_marks` → `SaveQuests.npc_state`
  ran three full side-quest scans per loaded NPC.
- `build_highlight_ring` compiled a new `Shader` (+ material + mesh) for every chest / door / NPC spawned.
- `TownLife._process`: 200-370 µs/frame driving every townsperson in loaded town chunks, on-screen or not.
- **Leak:** `ChunkRenderer._build_walls_physics` built a `WallCollision` StaticBody3D for every chunk and only
  parented it when the chunk had walls — wall-less chunks leaked the node + its physics body forever
  (orphans grew 74 → 112 over a 900-frame walk; the "GodotBody3D RIDs leaked at exit" warning).
- MAX_KICKS_PER_FRAME 2 → 1 was tried and measured: within noise, reverted.

## Plan

Fix each measured item without changing behaviour; prove equivalence where logic was restructured.

## Changes Made

- `tools/profile_world.gd` (new): the profiler above.
- `RealmLayout.stamp_context(cx, cz, true)` + `stamp_tile_in(ctx, …)`: per chunk, keep only towns / road
  segments / legend spots within reach; anything farther can only yield a distance ≥ BLEND_MARGIN, which stamps
  identically. `stamp_tile` is the same code over a cached full context. Margin chunks 5.95 → **1.06 ms**.
  Test `test_chunk_stamp_context_matches_full_stamp` checks every tile of every realm-touching chunk.
- `SaveQuests.npc_states()`: one pass → npc → state; `npc_state()` reads it; QuestTracker fetches it once per
  refresh. Test `test_npc_states_matches_per_npc_rule` compares with the old per-NPC rule over levels 1-11 and
  every quest's accept / finish states.
- `WorldEntityBase.build_highlight_ring`: one shared ShaderMaterial, one CylinderMesh per radius. Town-chunk
  entity spawn 1.66 → 0.75 ms.
- `TownLife`: walkers beyond FAR_RADIUS (40 u) are driven round-robin every 6th frame with the skipped time
  (positions are clock-derived, so they land exactly; only off-screen stepping is coarser). 206-370 → ~96 µs.
- `ChunkRenderer`: free the unused WallCollision body. Orphans after the walk: **0**; exit RID warning gone.
- `tests/chunk_unload_smoke.gd`: fails on any orphan node after streaming in (verified it fails without the fix).

Result (same walk): p99 27.5 → ~17 ms, max ~55 → ~29 ms, 0 frames on an unbuilt chunk.

## Documentation Updates

CLAUDE.md "Running Tests" names the profiler; BID-088 logs the remaining kick cost.
