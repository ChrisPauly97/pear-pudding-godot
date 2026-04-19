# TID-073: Create 6 New Weapon .tres Files

**Goal:** GID-022
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Only starter_dagger exists. This task creates 6 new weapons covering all WeaponData effect types so players have meaningful weapon choices and something to hunt for in the world.

## Research Notes

- Existing weapon: `data/weapons/starter_dagger.tres` — follow its WeaponData schema exactly
- `autoloads/WeaponRegistry.gd` loads weapons from `data/weapons/` — verify auto-discovery via dir listing
- Every .tres needs a `.uid` sidecar (see CLAUDE.md for generation command)
- WeaponData fields (check starter_dagger.tres): id, display_name, description, battle_effect_type, battle_effect_value, injected_card_id, injected_card_count
- Effect types to cover (from GID-014 docs):
  - `deck_inject`: inject N copies of a card at battle start
  - `starting_mana`: start battles with extra mana
  - `starting_hp`: hero starts with higher HP
  - `passive_atk`: hero attack stat increased

**Planned 6 weapons:**

| ID | Display Name | Effect Type | Effect Value | Injected Card | Notes |
|---|---|---|---|---|---|
| dawn_staff | Dawn Staff | deck_inject | 2 | mend | Injects 2 Mend spells — synergy with Dawn decks |
| dusk_blade | Dusk Blade | deck_inject | 2 | drain | Injects 2 Drain spells — synergy with Dusk decks |
| mana_crystal | Mana Crystal | starting_mana | 2 | — | Start each battle with 2 extra mana |
| iron_shield | Iron Shield | starting_hp | 10 | — | Start each battle with 40 HP instead of 30 |
| berserker_axe | Berserker Axe | passive_atk | 3 | — | Hero attack increased by 3 |
| ember_wand | Ember Wand | deck_inject | 3 | spark | Injects 3 Spark spells — burn deck support |

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
