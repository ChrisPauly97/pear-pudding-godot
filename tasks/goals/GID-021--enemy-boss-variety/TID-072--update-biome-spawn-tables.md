# TID-072: Update Biome Spawn Tables

**Goal:** GID-021
**Type:** agent
**Status:** pending
**Depends On:** TID-069

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The infinite world currently spawns only the 4 original enemy types regardless of biome. This task updates the spawn tables so each biome uses its biome-appropriate enemy pool, making exploration feel distinct.

## Research Notes

- `game_logic/world/InfiniteWorldGen.gd` or `game_logic/world/BiomeDef.gd` — find where enemy types are assigned to spawned entities; search for enemy type strings like `"undead_basic"`
- `game_logic/world/ChunkData.gd` may hold the entity list for a chunk
- Target enemy distribution per biome:
  - grasslands: undead_basic, undead_horde, wraith
  - forest: undead_basic, forest_shade, ghoul_pack
  - desert: sand_stalker, undead_horde
  - scorched: scorched_revenant, undead_elite
  - mountains: mountain_troll, stone_golem
- Boss enemies should NOT appear in the infinite world spawn tables — they are named-map only
- Keep spawn weights so some biomes feel harder (mountains/scorched = tougher enemies predominantly)
- Strict mode: if enemy type is stored as a String, use `EnemyRegistry.get_enemy(type_id)` to validate the ID exists before using it

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
