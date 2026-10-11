# TID-791: Gear sources follow the curve

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-790

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The player should get **regular** upgrades: drops, quest rewards, vendors and crafting hand out items of the band
for the zone / enemy level, so a player who plays normally is wearing on-curve gear (this is what the balance
profile in TID-778 assumes). Add a pity rule so a slot never lags more than one band behind.

## Research Notes

- Drops: `scenes/world/modules/ChestLoot.gd` (owned / unowned pool, `UPGRADE_DROP_CHANCE`, `SaveGear.roll_for`,
  `GameBus.equipment_dropped`); enemy drop tier from `EnemyRegistry` / `ZoneLevels`.
- Quests: `GearRolls.QUEST_RARITY`; quest rewards in `SaveQuests.gd` / `StoryQuests`.
- Vendors: merchant / blacksmith (`BlacksmithScene.gd`); crafting: `game_logic/professions/CraftedGear.gd`.
- Expose `GearCurve.expected_loadout(level)` (pure) — the same table the sim profile reads, so content and balance
  share one definition.

## Plan

## Changes Made

## Documentation Updates
