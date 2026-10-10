# TID-760: Gathering nodes in the world

**Goal:** GID-182
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
