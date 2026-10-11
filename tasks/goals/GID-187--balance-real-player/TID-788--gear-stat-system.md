# TID-788: Gear stat system (WoW-style stats wired into combat)

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-10-11): gear should curve from basic single-stat items (health only / armour only) to items with
secondary stats, "all of the above, perhaps also add new stats like WoW does". Gear should be about **60 % of a
level-30 player's power** (the rest from levelling).

Today an item has one `battle_effect_type` (starting_hp, starting_armor, starting_mana, passive_atk, offhand_atk,
deck_inject) scaled by `GearRolls.mult` (rarity × 2 % per ilvl). Flat values (chainmail +12 HP) vanish against a
level-30 hero (175 HP).

Build pure `game_logic/items/GearStats.gd`: the stat table, how each stat converts to a combat effect, and
rating-per-% that grows with level (WoW-style, so old gear fades). Proposed stats (user to confirm the list):

| Stat | Effect | Bands |
|---|---|---|
| Stamina | + max HP | all |
| Armor | soaks damage (`HeroState.armor`) | all |
| Power | + % outgoing damage (all schools) | Fine+ |
| Crit | + crit chance (`crit_chance` path, swings + spells) | Fine+ |
| Haste | − GCD / cast / swing time | Fine+ |
| Spirit | + mana regen | Fine+ |
| Intellect | + max mana | Fine+ |
| Mastery (school) | + % damage of one school (replaces the `school_dmg` affix) | Superior+ |
| Versatility | + % damage dealt and − % damage taken | Superior+ |
| Leech | heal for % of damage dealt | Superior+ |
| Block | off-hand: chance to halve a hit | Superior+ |
| Resist (school) | − % damage of one school (replaces the `school_resist` affix) | Superior+ |

## Research Notes

- Effects applied in `BattleSetup.apply_gear` (sim + game) and `BattleModifiers._apply_equipment_effects`.
- Hooks: max HP `HeroState.max_health`; armor `HeroState.add_armor`; outgoing `DamageResolver.power_mult`
  (`school_power`, `level_power` — GID-186); crit `PlayerCaster.modify_power` + `RealtimeCombat` swing crit
  (`crit_chance`); timing `RealtimeCombat._gcd_total`, `swing_speed`, cast times in `PlayerCaster`; mana
  `max_mana_for(level, bonus_mana)`, regen `mana_regen`; resist `DamageSchools.capped_resists` (`max_player_resist`).
- Conversion knobs go in `CombatTuning` (rating per 1 % at level L), not constants.
- Turn-based: Stamina / Armor / Power / Intellect / Resist apply; timing stats are real time only.

## Plan

## Changes Made

## Documentation Updates
