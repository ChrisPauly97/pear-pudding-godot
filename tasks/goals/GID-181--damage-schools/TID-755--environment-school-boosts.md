# TID-755: Weather / battlefield / night school boosts

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-749

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The world rewrites battle rules (spec positioning); schools give weather and time of day a clear, readable effect on which deck to bring.

## Research Notes

- `game_logic/battle/BattlefieldRules.gd`: `modify_damage(base, biome)` L106, `branch_affinity_active(branch, biome, is_night)` L112 (existing branch/biome affinity — extend rather than duplicate), `compute_is_night` L160.
- Weather: `scenes/battle/modules/BattleModifiers.gd` `_apply_weather_battle_init` L121, battle weather in `_battle._battle_weather`. Move the school part into pure BattlefieldRules (e.g. `school_env_mult(school, biome, weather, is_night)`) so the sim can use it; the TID-749 resolver multiplies it in.
- Proposed table: night +dark, day +light, storm +rift, rain +verdant, ash_fall/scorched +… — final table in Plan; keep magnitudes small (×1.1–1.2), knobs in CombatTuning.
- Battle banner text (BattleArena label/banner) should show the active boost.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
