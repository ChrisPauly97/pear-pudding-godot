# TID-750: Material drops from enemies

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-748

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Gives cooking and crafting a combat-fed source: beasts drop meat and hide, magical enemies drop cores.

## Research Notes

- Victory rewards: `autoloads/scene_manager/BattleVictory.gd` `_on_battle_won` (also `_reward_joined_enemies` for team fights). Add a material roll beside the coin/XP/card reward and show it in `_show_reward_toasts`.
- Drop table: per enemy family in `ProfessionDefs` (e.g. `DROPS_BY_FAMILY`), keyed by enemy_type/family read from `EnemyRegistry._ensure_loaded()` data (enemy data lives only there — no `.tres`). Quantity scales with the difficulty tier, like `GearRolls.TIER_WEIGHTS`.
- Co-op loot: check `game_logic/net/LootRoll.gd` — materials go to each peer locally (no need/greed).
- Exclude practice/duel/puzzle/scripted fights (mirror `HeroVitality.carries_over` rules).
- Test: pure drop-roll function with a seeded RNG.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
