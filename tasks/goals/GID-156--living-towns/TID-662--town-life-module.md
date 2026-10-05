# TID-662: TownLife World Module — Move Townsfolk, Sync Interaction Data

**Goal:** GID-156
**Type:** agent
**Status:** pending
**Depends On:** TID-661

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Drives the TID-661 plan in the live world: each frame, moves walker nodes to their computed positions, keeps the
data the interaction chain reads in step, and freezes a walker while the player talks to them.

## Research Notes

- New module `scenes/world/modules/TownLife.gd` (`town_life`), created in `WorldScene._ensure_world_modules()`
  like `Critters` / `StarterCamps`; typed back-ref `_world: _WorldScene`; add a typed field on WorldScene.
  Module rules: no bare `add_child`/`self` (`test_scene_module_guardrail`). Add a row to the modules table in
  CLAUDE.md.
- NPC registry on WorldScene: `register_npc(nid, node, n_data)` (~line 1030) fills `_npc_nodes` (id → node) and
  `_active_npc_data` (id → dict with x/z). `_find_nearby_npc` = `_first_data_in_range(_active_npc_data, …)`, so
  **update `n_data["x"]/["z"]` as walkers move** or the prompt stays on the start tile. Minimap gets `_npc_nodes`
  so it follows the node automatically.
- Nodes come and go with chunk streaming (`ChunkRenderer.gd` ~line 661 spawns `TownspersonNPC.tscn`). Read nodes
  via `_world._valid_node3d(_npc_nodes.get(id))` every tick (freed-node rule in CLAUDE.md).
- Only active in stitched towns: gate on `_world.current_town` (set by `RealmRegions`) and on the hero being
  within N tiles; skip when not `_is_infinite` overworld.
- Height: `_world.get_terrain_height(x, z)`. Facing: flip the billboard (`Sprite3D.flip_h`) by move direction;
  remember `offset` is not mirrored by flip_h (CLAUDE.md mount learning).
- Idle life: `TownspersonNPC` registers `_IdleLife.STYLE_BREATHE` + `IdleLoop` blink; add a light walk bob while
  moving (see `Critter.gd` hop, `game_logic/IdleLife.gd`).
- Talk pause: when `NpcInteractions` opens dialogue for a walker, hold it (store paused offset so it resumes its
  loop without teleporting — e.g. resume by shifting its personal time offset). Face the player.
- Co-op: positions from the synced clock (TID-661), no RPC. Verify host/joiner agree in a smoke test if feasible.
- Tests: extend `tests/world_scene_smoke.gd` or new test that a moved walker's `_active_npc_data` x/z matches its
  node, and that `_find_nearby_npc` finds it at its new spot. Run `scripts/unsafe-hits.sh` + gdlint.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
