# TID-656: Perrine's Bottomless Pudding — Legendary Item

**Goal:** GID-153
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The reward must feel rewarding and permanent: a unique flask that is never consumed. One sip per battle: full heal,
clear statuses, +1 mana. Shares the normal potion cooldown so it can't stack with other potions in the same window.

## Research Notes

- Potions: `game_logic/GardenDefs.gd` (`POTIONS`, `POTION_RECIPES`); counts in `SaveManager.potions`
  (`SaveManager.garden.add_potions/remove_potions`). See `docs/agent/home-garden-potions.md`.
- Quick slots: `SaveManager.quick_slots`, `game_logic/battle/QuickSlots.gd` `resolve(slots, potions)` drops
  exhausted ids — the pudding must count as always owned when `SaveManager.has_story_flag("legend_pudding_owned")`
  (or a dedicated persisted bool via one `PERSISTED_FIELDS` entry).
- Battle: `scenes/battle/modules/BattleConsumables.gd` `_apply_potion_effect(potion_id)` decrements the count,
  starts cooldown, emits `GameBus.potion_used`. Add a `pear_pudding` branch that does NOT decrement; track
  "sipped this battle" on the module (not persisted — refills per battle). Full heal `hero.health = hero.max_health`;
  statuses via `game_logic/battle/StatusEffects.gd`; mana `mini(hero.mana + 1, hero.max_mana)`. Turn-based and
  real-time (`consumables.tick_quick`) paths both.
- Backpack Items tab (InventoryScene `ItemsPanel`, Q/E assign) — show it with a gold "Legendary" tint and
  "Refills every battle" line.
- Icon: render the flask from `tools/generate_app_icon.py` (`_flask`) to `assets/icons/items/pear_pudding.png`
  (+ `.import`), `preload` it (Android rule).
- Tests: never decremented, once per battle, refills next battle, resolve() keeps it slotted, save round-trip.

## Plan

Model the pudding as a potion id with a `legendary` flag so quick slots, the bag and PvP relay reuse the potion
path. Owned = `potions[id] == 1`; never decremented. One-sip-per-battle state lives on a per-battle
`LegendaryPotions` instance in BattleConsumables. Shared effect helper for local + PvP host. Hidden from the bag
until owned. Icon from the app-icon flask.

## Changes Made

- `game_logic/GardenDefs.gd`: `pear_pudding` POTIONS entry (`legendary`), `is_legendary()`.
- `game_logic/battle/LegendaryPotions.gd` (new): per-battle sip gate, `apply_pear_pudding(hero)`.
- `game_logic/battle/StatusEffects.gd`: `AILMENTS`, `clear_ailments()`.
- `scenes/battle/modules/BattleConsumables.gd`: legendary branch (no consume, once per battle, "∞"/"sipped" label).
- `scenes/battle/net/BattleNet.gd`: host applies a client's pudding sip.
- `autoloads/save_manager/SaveGarden.gd`: `grant_legendary()`.
- `scenes/ui/inventory/ItemsPanel.gd`: legendary row hidden until owned, gold tint, flask icon.
- `tools/generate_app_icon.py`: also writes `assets/icons/items/pear_pudding.png`.
- `tests/unit/test_legendary_potions.gd` (new, 6 tests). Full suite + battle smokes pass, no SCRIPT ERROR.

## Documentation Updates

`docs/agent/home-garden-potions.md`: Legendary Potion section.
