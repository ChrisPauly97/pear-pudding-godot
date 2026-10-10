# TID-748: DamageSchools pure module + CombatTuning knobs

**Goal:** GID-181
**Type:** agent
**Status:** done
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

## Plan

1. `game_logic/battle/DamageSchools.gd`: pure RefCounted. `all_schools`, `is_school`, `school_of(card)`, `outcome(school, profile)` (immune > resist > weak), `mult(school, profile, tune)`, `scale(damage, ...)` (rounding helper, zero multiplier = 0, else at least 1).
2. `CombatTuning.DEFS`: `resist_mult` 0.5, `weak_mult` 1.5, `immune_mult` 0.0 in group "Damage schools".
3. Tests in `tests/unit/test_damage_schools.gd` (the runner only auto-discovers `tests/unit/test_*.gd`, so the file lives there rather than `tests/`).
4. Docs: `docs/agent/damage-schools.md`, row in CLAUDE.md docs table.
5. TechniqueDefs school field: skipped. Technique `.tres` cards already carry `magic_type`, so `school_of` covers them.


## Changes Made

- `game_logic/battle/DamageSchools.gd` (new): `all_schools()`, `is_school(s)`, `school_of(card)` (CardInstance, Object with `magic_type`, or Dictionary; invalid or missing → `physical`), `outcome(school, profile) -> "immune"|"resist"|"weak"|""`, `mult(school, profile, tune = null) -> float`, `scale(damage, school, profile, tune = null) -> int`.
- `game_logic/battle/CombatTuning.gd`: knobs `resist_mult` (0.5), `weak_mult` (1.5), `immune_mult` (0.0), group "Damage schools". Nothing reads them yet, so no gameplay numbers change.
- `tests/unit/test_damage_schools.gd` (new): 20 assertions. Runner auto-discovers it.
- TechniqueDefs: no school field added. Technique `.tres` cards already have `magic_type`, and `school_of` reads it.
- Validation: editor parse clean; `unsafe-hits.sh` exit 0, no hits; gdlint clean; runner PASS (3240 passed, 0 failed), 0 `SCRIPT ERROR`.


## Documentation Updates

- New `docs/agent/damage-schools.md` (Key Features / How It Works / Integrations).
- CLAUDE.md docs table: row added for `damage-schools.md`.
- `tasks/index.md` and `goal.md` progress: TID-748 done (2 / 11).

