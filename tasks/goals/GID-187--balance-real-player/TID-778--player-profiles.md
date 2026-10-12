# TID-778: Player profiles (typical build per level)

**Goal:** GID-187
**Type:** agent
**Status:** done
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

Pure `BalanceProfiles`: `cfg(level, magic_type, kind)` for `typical` / `modest` / `bare`, a deterministic skill build,
the magic type's matched deck plus skill-granted techniques, and the `GearDrops.expected_loadout` gear; a `profiles`
coverage section (progression order gated now, level targets in TID-787).

## Changes Made

- `game_logic/battle/BalanceProfiles.gd`: `cfg`, `skill_build` (first branch row by row, prerequisites first, then the
  second; skips `alt_cost` nodes — a tree has ~10-11 nodes per magic type, below the 21 points of level 30), `deck`
  (skill techniques fill free technique slots), `measure` / `check` (`profiles` section: 9 cells levels 2-59, every
  magic type, typical / modest / bare, +0 / +1; gate: typical ≥ modest ≥ bare − 15 pp), `power_of` / `gear_share`
  (TID-787 measurement).
- `BalanceFight` records `taken` / `hero_max_hp` (for `power_of`). `BalanceCoverage` dispatches `profiles`.
- Measured (8 fights × 4 types, +1): bare 50-100 %, modest 91-100 %, typical 88-100 % — profiles win nearly every
  cell, so TID-787 retunes against them. Gear share at level 30 (rift echo): 0.48 (target 0.6).
- Tests: `tests/unit/test_balance_profiles.gd` (6).

## Documentation Updates

- `docs/agent/balance-sim.md` → Player profiles.
