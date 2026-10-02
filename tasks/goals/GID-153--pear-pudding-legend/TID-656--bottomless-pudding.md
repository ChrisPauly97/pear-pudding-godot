# TID-656: Perrine's Bottomless Pudding — Legendary Item

**Goal:** GID-153
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
