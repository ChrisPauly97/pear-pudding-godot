# TID-538: Gear Rarity, Item Level & Quest Reward Choice

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** TID-533, TID-536

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Better gear as you explore: rarity tiers, item level scaled to enemy level, and a choose-one reward on quest turn-in.

## Research Notes

- Gear: `data/WeaponData.gd` (slot, battle_effect_type/value, injected_card_id/count), `autoloads/WeaponRegistry.gd`,
  slots `equipped_weapon/armor/ring/trinket` in SaveManager, `scenes/ui/CharacterScene.gd`,
  drops in `scenes/world/modules/ChestLoot.gd`. Card rarity already exists (GID-028) — reuse its colours.
- Item instances need per-drop stats (rarity, ilvl) — owned gear is currently id strings (`owned_weapons`); needs an
  instance dict + save migration. BID-033 notes session equipment gaps for co-op.

## Plan

1. One roll per owned item id (`gear_rolls`), not per-drop instances: avoids migrating the owned lists;
   a duplicate drop upgrades the roll instead of being wasted.
2. `game_logic/items/GearRolls.gd` (rarity weights by tier, item level, multiplier) + `SaveManager.gear`
   module (`SaveGear.gd`: `roll_of`, `mult`, `grant`).
3. `UpgradeDefs.effective_stat` / `get_display_string` take the roll multiplier; battle + real-time
   off-hand + Character screen pass it.
4. Drops: chests (tier, zone level), victory weapon rewards, shop (common at your level).
5. Quest reward choice: `gear_choice` on five side quests; turn-in panel shows the picks.

## Changes Made

- New `game_logic/items/GearRolls.gd`, `autoloads/save_manager/SaveGear.gd` (+ uids).
- `SaveManager` (`gear_rolls`, `gear` module), `UpgradeDefs`, `BattleModifiers`, `BattleRealtime`,
  `ChestLoot`, `BattleVictory`, `ShopScene`, `CharacterScene`, `SideQuests` (5 gear choices),
  `SaveQuests.turn_in(id, pick)`, `NpcInteractions` (gear choice row, reward text).
- Tests: new `test_gear_rolls.gd`.
- Not done: co-op session loot (BID-033 records) doesn't carry rolls.

## Documentation Updates

- `inventory-and-deck.md` → Rarity & item level.
