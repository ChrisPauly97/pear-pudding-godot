# TID-536: Zone Level Ranges & Enemy Levels

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

WoW zones have level ranges; enemies show a level coloured relative to yours (grey/green/yellow/orange/red) and XP scales accordingly.

## Research Notes

- XP/level: `SaveManager.xp_for_level` / `_compute_level` (~L1163), XP granted on victory (~L1214). BID-049 context.
- Enemy difficulty: `EnemyRegistry.get_difficulty_tier(type)`; biomes in `BountyGen.BIOME_NAMES`; infinite world
  chunking in `docs/agent/world-generation.md`. Level = f(biome, distance from spawn) for infinite world; named maps
  get an authored range.
- Enemy level must affect battle (HP/attack scaling like `CoopBattleScaling.gd`) and XP (grey = 0 XP).
- Show level on enemy name tag (`SpriteRegistry.make_name_label`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
