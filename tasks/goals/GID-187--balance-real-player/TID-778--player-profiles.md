# TID-778: Player profiles (typical build per level)

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-791

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The sim's player is `BattleSetup.level_deck(learned)` (starter deck + up to 3 techniques), no gear, no skills. Past
level ~10 no real player looks like that. Build `game_logic/battle/BalanceProfiles.gd`: `profile(level, magic_type,
kind)` → a `BattleSetup.build` cfg fragment (deck, gear, skills, learned). `kind` = `typical` (average expected) or
`modest` (floor).

## Research Notes

- Deck: collection growth comes from chest drops (`EnemyRegistry.get_drop_pool`), packs (`docs/agent/card-packs.md`),
  crafting (`CraftedGear`, professions), card upgrades (`UpgradeDefs.MAX_LEVEL`, `BlacksmithScene`). Magic-type cards
  via `MagicTypes` + `CardRegistry` (`card.magic_type`). Deck rules: `TechniqueDefs.DECK_MAX`, `UnlockLadder`
  (technique slots, hand size, draw rows — `BattleSetup.apply_deck_rules`).
- Gear: the typical profile wears `GearCurve.expected_loadout(level)` (TID-791); the modest profile one band
  behind. Legacy notes: `game_logic/items/GearRolls.gd` (`roll(tier, level, rng, weapon)`, `mult`, affixes); `BattleSetup.apply_gear`
  takes `[{id, level, mult, affix}]`; weapon speed / off-hand via `weapon_speed_for_item` / `offhand_damage_for_item`.
- Skills: `cfg.skills` → `SkillMods` + school nodes (`apply_school_power`, `school_resist_sources`); skill points from
  level 10 (`SaveManager._restore_derived_fields`). Pick a deterministic "typical" spend per magic type.
- Derive "typical" from the game's own curves (drop tier by zone level, `ZoneLevels`), not hand-picked numbers, so a
  content change moves the profile too.
- Keep bare-hero cells (`BalanceCoverage`) as a floor; profiles become the gating player.

## Plan

## Changes Made

## Documentation Updates
