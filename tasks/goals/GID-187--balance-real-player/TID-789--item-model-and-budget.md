# TID-789: Item model, bands and stat budget

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-788

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Hand-made items (user, 2026-10-11): every item authored with fixed stats. Give `WeaponData` a `stats` dictionary,
`item_level`, `level_req`, `band` and `rarity`, and a budget formula so authored items stay on the curve.

Proposed bands:

| Band | Levels | Shape |
|---|---|---|
| Basic | 1-9 | one stat: Stamina **or** Armor (weapons: plain damage) |
| Fine | 10-19 | Stamina/Armor + one secondary |
| Superior | 20-34 | primary + two secondaries (Mastery / Versatility / Leech / Block / Resist open) |
| Heroic | 35-49 | primary + three secondaries, higher budget |
| Legendary | 50-60 | Heroic + one unique effect (proc / passive) |

- Budget = f(item level, slot weight, rarity); `test_gear_budget` fails if an authored item is off budget by more
  than a tolerance, so the catalogue can't drift.
- Rarity is authored per item (common / rare / epic / legendary), not rolled; `GearRolls` random rarity / ilvl /
  affix rolls retire (school affixes become Mastery / Resist stats).
- Existing 28 items (`data/weapons/*.tres`) map onto Basic / Fine with their stats rewritten to the new model.

## Research Notes

- `data/WeaponData.gd` (slot, battle_effect_type, battle_effect_value, injected_card_id, swing_speed),
  `autoloads/WeaponRegistry.gd`, `UpgradeDefs.effective_stat(weapon, level, mult)` (blacksmith upgrades),
  `GearRolls.gd` (rarity / ilvl / affix), `SaveGear.gd` (`gear_rolls` per item id, `grant`, `roll_for`).
- Slots: weapon, armor, ring, trinket, offhand, shoulders, helmet, boots (`SaveManager.equipped_*`).
- deck_inject weapons (dawn staff, ember wand…) keep their card injection as the item's unique effect.
- Save migration (`SaveMigrations.gd`): old `gear_rolls` drop; owned item ids keep working.

## Plan

## Changes Made

## Documentation Updates
