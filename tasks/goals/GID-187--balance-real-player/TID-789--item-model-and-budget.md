# TID-789: Item model, bands and stat budget

**Goal:** GID-187
**Type:** agent
**Status:** done
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

1. `WeaponData`: `band`, `item_level`, `level_req`, `rarity` exports (stats came with TID-788).
2. Pure `game_logic/items/GearCurve.gd`: `BANDS` (Basic 1-9, Fine 10-19, Superior 20-34, Heroic 35-49, Legendary
   50-60), `band_for_level`, primary / secondary stat sets and max secondaries per band (Superior+ opens mastery,
   leech, block, resist), `SLOT_WEIGHT`, `RARITY_BUDGET`, per-rating `STAT_COST`, `budget(il, slot, rarity)`,
   `cost(stats)`, `validate(weapon)` (shape + budget ±`BUDGET_TOLERANCE`; `deck_inject` / `offhand_atk` items are
   weapon mechanics with a budget ceiling only).
3. Convert the 28 items: starting_hp → stamina, starting_armor → armor, starting_mana → intellect, passive_atk → attack_power
   (10 rating per old ATK point); item level solved from the budget; band from item level; rarity common;
   `battle_effect_type` cleared (deck_inject / offhand_atk keep theirs).
4. `BattleSetup.apply_gear`: an item's stats scale with its blacksmith upgrade level (`UpgradeDefs.stat_scale`, +10 % per level);
   rarity / ilvl rolls no longer touch stat items (rarity is authored). `UpgradeDefs.get_display_string` lists stats.
5. `tests/unit/test_gear_curve.gd` (every registered item validates; budget / band rules). Drops and the roll /
   affix retirement + save cleanup are TID-791; full tooltips TID-792.

## Changes Made

- `data/WeaponData.gd`: `band`, `item_level`, `level_req`, `rarity`.
- `game_logic/items/GearCurve.gd` (new): bands, primary / secondary / advanced stat sets, `STAT_COST`, `SLOT_WEIGHT`,
  `RARITY_BUDGET`, `budget()` = slot × (6 + 1.2 × item level) × rarity, `cost()`, `validate()` (±20 %).
- All 28 `data/weapons/*.tres` moved onto stats (hp → stamina, armor → armor, mana → intellect, ATK → 10
  attack_power per point); item level solved from the budget (23 Basic, 2 Fine, 2 Superior); five under-budget early
  items raised to budget (leather cap 3 → 6 Stamina, warded cloak 4 → 7, leather pauldrons 4 → 5, travel boots 3 → 4,
  iron helm 2 → 3 Armor); descriptions keep the flavour line only. `deck_inject` / `offhand_atk` items keep their
  mechanic.
- `UpgradeDefs.scaled_stats` / `stats_string` (+10 % per blacksmith level); `get_display_string` lists stats;
  `BattleSetup.apply_gear` uses the scaled stats.
- Tests: `tests/unit/test_gear_curve.gd` (7); `test_head_feet_equipment` / `test_offhand_equipment` assert stats.
- Backlog: BID-106 (`inventory_tiles_smoke` already failing on main, unrelated).
- Left for TID-791: drop rolls (`GearRolls` rarity / ilvl / affix) still roll and save but only touch legacy
  mechanic items; retire them with the drop rework.

## Documentation Updates

- `docs/agent/inventory-and-deck.md` → Gear Curve.
