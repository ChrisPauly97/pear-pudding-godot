# TID-748: DamageSchools pure module + CombatTuning knobs

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation of GID-181: one pure table/function deciding how much a hit of school S does to a target with profile P. Everything else in the goal calls it.

## Research Notes

- New `game_logic/battle/DamageSchools.gd` (RefCounted, pure, no autoloads — balance sim and `-s` tests load it). Needs a `.uid` sidecar? No — plain `.gd` doesn't.
- Schools: `physical` + the four magic types from `game_logic/MagicTypes.gd` (`light`, `dark`, `verdant`, `rift`). Read types from MagicTypes; never re-list them (CLAUDE.md → MagicTypes is source of truth). Optional element sub-tag per branch can be added to MagicTypes' table later — keep the API `school_of(card)` so it can grow.
- Card → school: `CardInstance.magic_type` (game_logic/battle/CardInstance.gd:17). 270/304 cards in data/cards have a magic_type; the rest (enemy units like ghost/skeleton) → `physical`. Techniques (`TechniqueDefs`) need a school field (Strike/Kick physical, Mend n/a heal).
- API sketch: `school_of(card) -> String`, `mult(school, profile: Dictionary, tune) -> float` where profile = `{resist: {school: true}, weak: {...}, immune: {...}}`, `outcome(school, profile) -> "weak"|"resist"|"immune"|""` for UI.
- Knobs go in `game_logic/battle/CombatTuning.gd` (`resist_mult` 0.5, `weak_mult` 1.5, `immune_mult` 0.0) — CLAUDE.md: add knobs there, not constants. Rounding: `maxi(1, roundi(d*m))` unless immune.
- Tests: new `tests/test_damage_schools.gd`; register in tests/runner.gd. Check the runner pattern for registration.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
