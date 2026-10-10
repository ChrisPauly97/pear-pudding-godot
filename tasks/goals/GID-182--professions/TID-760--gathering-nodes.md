# TID-760: Gathering nodes in the world

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-759

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Gives materials a place in the world: herb patches, ore veins and fishing spots that the hero harvests.

## Research Notes

- Spawn in `game_logic/world/InfiniteWorldGen.gd` `generate_chunk*` (runs on worker threads — must stay pure; any new lazily-built static goes in `InfiniteWorldGen.warm()`; see `docs/agent/world-generation.md` → Threading). Pick by biome: herbs in grassland/forest/bog (`WaterMath.bog_at`), ore in mountains/caves (`CaveGen` dungeons), fishing spots on river banks/coast (`Rivers`, `Coast`). Deterministic per chunk seed (co-op joiners generate the same world — CLAUDE.md bug learnings).
- Entity: `scenes/world/entities/GatherNode.gd` extends `WorldEntityBase`; billboard via `SpriteRegistry.make_billboard()`. Harvest = short timed action (hold), interrupted by an enemy engage.
- Interaction: add `gather_node` to `WorldScene.INTERACT_PRIORITY` (peaceful, so above the hostile entries) + a branch in both chains, or a row in `_try_simple_interaction`'s table; `test_interact_priority` enforces the order. Touch: the HUD interact button covers it.
- Yield: from `ProfessionDefs`; a little gathering XP goes to the profession that uses the material. A depleted node respawns after N in-game minutes (store depleted ids + time, prune on chunk evict; no permanent save list — see the Spire lesson in CLAUDE.md).
- Co-op: a harvest broadcast like a chest removal (`CoopSession` world-object sync).
- Profile with `tools/profile_world.gd` before and after (chunk landing cost).

## Plan

- Pure `game_logic/professions/GatherDefs.gd`: kinds (herb / ore / fish), per-biome yields, `plan_chunk(chunk_seed, biome, water_near)` (deterministic, worker-safe), profession mapping, respawn seconds, XP.
- `ChunkData.gather_nodes` filled at the end of `InfiniteWorldGen._gen_entities`; ChunkRenderer spawns `GatherNode` entities.
- `GatherNode` (placeholder mound): `harvest()` hides it for its respawn time; `interact()` grants the material and XP.
- Interact via `INTERACT_PRIORITY` (`gather_node`, after `riddle_spot`) and the `_try_simple_interaction` table; registry in `scenes/world/modules/GatherNodes.gd`.
- Tests in `tests/unit/test_gathering.gd`; docs in `docs/agent/professions.md`.

## Changes Made

- New: `game_logic/professions/GatherDefs.gd` (+ `.uid`), `scenes/world/entities/GatherNode.gd` / `.tscn`, `scenes/world/modules/GatherNodes.gd` (+ `.uid`), `tests/unit/test_gathering.gd`.
- `game_logic/world/ChunkData.gd`: `gather_nodes` field.
- `game_logic/world/InfiniteWorldGen.gd`: plants gather nodes at the end of `_gen_entities`.
- `scenes/world/ChunkRenderer.gd`: spawns gather nodes and registers them with `world_scene.gather_nodes`.
- `scenes/world/WorldScene.gd`: `gather_node` in `INTERACT_PRIORITY` (after `riddle_spot`), `gather_nodes` module field, `_find_nearby_gather_node` forwarder, a `GATHER` prompt, and a table row in `_try_simple_interaction`.
- `autoloads/save_manager/SaveProfessions.gd`: `add_xp(profession, n)`.
- Validation: compile, unsafe-hits and gdlint are clean. `tests/runner.gd` passes 3243 / fails 1: `test_worldscene_line_ceiling_guardrail` (WorldScene.gd is 1897-1898 lines against the 1890 ceiling, which main already sits at 1887). `world_scene_smoke` exits 0 with no SCRIPT ERROR.
- **Blocker:** the ceiling needs a decision. Raise it with review, or extract a cluster from WorldScene (for example the mana-well interaction). The ceiling was not raised here.
- Not done: co-op harvest broadcast, hold-time harvesting, bog moss planting, in-game-minute respawn (uses real seconds).

- Merge (orchestrator): the WorldScene line ceiling (1890) was cleared by moving `_on_scroll_collected` / `_show_narration_overlay` into `NamedMapProps` (`on_scroll_collected`, `show_narration_overlay`); crafting stations now interact through `_try_simple_interaction` (`CraftingStation.interact()` → `on_interact`), and `crafting_station` sits right after `gather_node` in INTERACT_PRIORITY. WorldScene is 1872 lines. Full suite 3265 passed, world smoke clean.

## Documentation Updates

- `docs/agent/professions.md`: new "Gathering (TID-760)" subsection, the Integrations line moved off "Planned", and the Tests paragraph mentions `test_gathering.gd`.
