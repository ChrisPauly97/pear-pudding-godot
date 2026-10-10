# TID-777: Balance coverage suite + level / school tuning

**Goal:** GID-186
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md.

## Research Notes

- First wide measurement (30 fights, default deck): Chapter 1 in band; past level 12 almost every same-level cell
  was 0 % (rift echo L20, frost wendigo L25, undead elite L30). Enemy HP grows ~17x by L30 (zone x
  `enemy_hp_per_level`), hero damage was flat, and authored tier-3/4 types fought at that tier from their first level.
- Long fights are lost to deck fatigue (~55 s), so a slow kill is a loss: win rates move in cliffs.
- Physical-resistant types (scarab, spectres, raider 3, frost wendigo, cactus worm, wraith) walled the all-physical
  default kit at 0 %; physical-weak types (raiders 1/2, isfig 2, sand stalker, ember cultist, troll, wolves) were
  walkovers — a physical tag scales the whole kit (auto-attacks, Strike, Allies).
- `SpellEffectResolver` passed `tune = null` to `DamageResolver`, so spell hits ignored the fight's tuning (the
  tuning panel's matchup knobs never touched spells). Defaults still applied.
- With the stock matched deck (2 school cards) a magic school's tag barely moves a fight; the matrix uses a
  school-heavy deck (6 swaps) and compares against the same enemy with only that tag removed.

## Plan

1. `BalanceCoverage` + `tests/balance_coverage.gd` (sections, `--tune`), parallel CI step.
2. Hero damage keeps pace with enemy HP past level 8 (`power_track`, `PlayerState.level_power`).
3. Every type takes its fight tier from its level (`base_tier` = 1); `default_enemy_level` for data without a level.
4. Milder physical matchup knobs; per-type `rt_hp_mult` for the outliers; re-pick saturated school-band cells.

## Changes Made

- `game_logic/battle/BalanceCoverage.gd`, `tests/balance_coverage.gd`, `.github/workflows/tests.yml` (four
  sections in parallel, ~90 s).
- `CombatTuning`: `power_track` 0.8, `power_from_level` 8 (`hero_level_power`, `enemy_hp_growth`),
  `physical_resist_mult` 0.8, `physical_weak_mult` 1.15. `DamageSchools.mult` reads the physical knobs.
- `PlayerState.level_power` (set by `RealtimeCombat` for the player), multiplied in `DamageResolver.power_mult`.
- `BattleSetup.base_tier` → 1 for every type; `default_enemy_level`; `untag_school` fight option;
  `school_matched_deck(…, swap)`. `BattleRealtime` start + `join_enemy` use the enemy's level (a joiner was level 1).
- `SpellEffectResolver.tune` (set by `BattleRealtime` / `BalanceFight`) — fixes spells ignoring the fight tuning.
- `EnemyRegistry` `rt_hp_mult`: raider 2 1.35, isfig 2 1.4, ember cultist 1.3, troll 1.2, sand stalker 1.4,
  cactus worm 0.9, wraith 0.9, spectre dread 0.7, raider 3 0.85, spectre haunt 0.85, scarab 0.75, frost wendigo 0.9,
  barrow king 0.75, roaming terror 0.85, blight heart 0.95.
- `BalanceBands`: desert / scorched / mountains roster cells and the matchup cell re-picked (old ones saturated).
  Baseline re-measured (only wolf-pack fight lengths moved).
- Tests: `test_balance_coverage.gd`, `test_level_power.gd`.

## Documentation Updates

- `docs/agent/balance-sim.md` (coverage suite, measurements), `docs/agent/damage-schools.md` (physical knobs),
  `CLAUDE.md` (Running Tests).
