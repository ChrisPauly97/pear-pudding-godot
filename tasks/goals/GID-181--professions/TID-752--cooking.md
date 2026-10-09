# TID-752: Cooking recipes + well-fed buffs

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-750, TID-751

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cooking turns meat, fish and herbs into foods that heal out of combat and give a 'well fed' buff for the next fights.

## Research Notes

- Foods are now `HeroVitality.FOODS` (`travel_bread`, `roast_fowl`; merchant-only). Extend that table with cooked foods (or have `ProfessionDefs` outputs point at new FOODS ids); keep the eat-over-time behaviour (`meal_rate`, `best_world_item`).
- Well fed: eating a cooked food sets a buff (stat + remaining fights or minutes) stored in a new persisted field; applied at battle start in `scenes/battle/modules/BattleModifiers.gd` (next to equipment/companion modifiers). Examples: +max HP, +auto-attack damage, faster mana. The HUD shows a small icon with the time left.
- Real-time combat timings come from `CombatTuning.gd` — buff magnitudes go there or in ProfessionDefs, not as magic numbers.
- Re-run `tools/balance_sim.gd`; buffs must not break `tests/balance_bands.gd` (the bands run unbuffed — keep it that way and note it in `docs/agent/balance-sim.md`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
