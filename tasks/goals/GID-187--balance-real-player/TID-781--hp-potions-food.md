# TID-781: Starting HP, potions and food

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Real fights often start wounded (persistent HP, `HeroVitality`). Add cfg `start_hp_frac`, bot use of quick-slot
potions and food buffs, and bands: a typical player at 60 % HP still wins same-level fights most of the time; a
"second fight in a row" chain (carry HP, regen between) is winnable; potions help without being mandatory.

## Research Notes

- `BattleModifiers._apply_persistent_hp` / `record_persistent_hp` (`SaveManager.hero_hp_frac`, `RESPAWN_FRAC`),
  `scenes/world/modules/HeroHealth.gd` (out-of-combat regen, meals).
- Potions: `QuickSlots.gd`, `PotionEffects.gd`, `LegendaryPotions.gd`, `BattleConsumables.gd`, `potion_cooldown` knob.
- Food: `game_logic/professions/WellFed.gd` (+max HP for a few fights) — `balance-sim.md` says buffs stay out of
  the baseline; band them separately, not in the default profile.

## Plan

## Changes Made

## Documentation Updates
