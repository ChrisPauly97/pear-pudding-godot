# TID-780: Fight conditions shared by sim and game

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Move battlefield conditions from `BattleModifiers` / `BattleScene` into pure `BattleSetup` (one path for sim and
game), add cfg keys, then band each condition's swing on a neutral profile cell (e.g. a condition moves win rate by
at most ±20 pp, and a school's favoured biome/time helps it).

## Research Notes

- `BattleModifiers._apply_weather_battle_init`, `_apply_weather_to_summoned` (rain ghosts, sandstorm, ash poison,
  snow discount), `_apply_school_environment` (TID-755 env boosts: `env_time_mult`, `env_biome_mult`,
  `env_weather_mult`), `_apply_desert_scorch`, `_apply_ambush_modifiers`, `_apply_gambit_handicaps` (`Gambits.gd`).
- `BattleScene` ~l.530 blight +5 HP (`is_blighted`), ~l.558 battlefield biome / night (`BattlefieldRules`).
- Ley-line Attuned buff on `HeroState` (`docs/agent/ley-lines.md`); night-hunt spectres (`docs/agent/night-hunts.md`).
- Watch the GID-176 doc rule: Well-Fed stays out of the CI baseline unless the user decides otherwise (TID-781).

## Plan

## Changes Made

## Documentation Updates
