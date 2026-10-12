# TID-791: Gear sources follow the curve

**Goal:** GID-187
**Type:** agent
**Status:** done
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

Pure `game_logic/items/GearDrops.gd` decides what every source hands out; call sites delegate to it; random rolls
retire (new grants record the item's authored rarity / item level, no affix; old saved rolls still read).

## Changes Made

- `GearDrops`: `candidates(level, slot, below)` (wearable: level_req ≤ level, item level ≥ level − 4; the slot's best
  wearable item stands in when the window is empty), `best_for`, `expected_loadout(level)` (for TID-778),
  `behind_slots` (empty, or ≥ 2 bands below → pity), `pick` (behind slots first, unowned first), `shop_stock`
  (one band window), `price` (stat budget × 4 + 20; legacy items keep their old price), `authored_roll`.
- Sources: `ChestLoot._maybe_drop_equipment` (zone level capped at the player's), `BattleScene` boss weapon fallback,
  `CoopActivities` loot roll (curve candidates for the winner's level), `ShopScene` stock / price / stat summary.
- Rolls: `SaveGear.roll_for` → authored roll; quest gear records the pick's own authored roll (`SaveQuests`).
  Removed ChestLoot's unused `UPGRADE_DROP_CHANCE` / `_STARTER_WEAPON`.
- Quest `first_spark` offered `buckler` (level 9) at quest level 5 → `arcane_focus` (level 3).
- Tests: `tests/unit/test_gear_drops.gd` (9); `test_gear_rolls` / `test_school_sources` updated for authored rolls.

## Documentation Updates

- `docs/agent/inventory-and-deck.md` → Gear Sources.
