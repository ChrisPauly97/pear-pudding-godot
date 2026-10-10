# TID-755: Weather / battlefield / night school boosts

**Goal:** GID-181
**Type:** agent
**Status:** done
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

Boost table (`BattlefieldRules.SCHOOL_ENV`, same row shape as `BRANCH_AFFINITY`, shared `_condition_met`):

- `dark` at night, `light` by day: `env_time_mult` x1.15
- `verdant` in Forest, `rift` in Scorched, `physical` in Mountains: `env_biome_mult` x1.1
- `verdant` in rain / heavy rain, `rift` in ash fall / volcanic, `light` in snow / blizzard, `physical` in sandstorm / dust devil: `env_weather_mult` x1.1 (no "storm" weather exists)

Stored once per side at battle start as `PlayerState.env_school_mult`; `DamageResolver` multiplies the hit's (attacker's) school by it, rounded once with the matchup. Balance sim never sets it, so it stays neutral.

## Changes Made

- `game_logic/battle/BattlefieldRules.gd`: `SCHOOL_ENV` table; `branch_affinity_active` now uses the shared `_condition_met`; `school_env_mult`, `school_env_table`, `school_env_text`.
- `game_logic/battle/CombatTuning.gd`: knobs `env_time_mult`, `env_biome_mult`, `env_weather_mult` (1.0–1.5); `default_f(key)` for pure callers.
- `game_logic/battle/DamageSchools.gd`: `apply_mult(damage, m)` (rounding shared with `scale`).
- `game_logic/battle/DamageResolver.gd`: `scaled_amount` multiplies matchup x boost; `env_mult(defender, school)`. `deal()` picks it up.
- `game_logic/battle/PlayerState.gd`: `env_school_mult: Dictionary` (not serialized).
- `scenes/battle/modules/BattleModifiers.gd`: `_apply_school_environment()` fills both sides' table; `BattleScene.gd` calls it after `set_battlefield_context`.
- `scenes/battle/modules/BattleArena.gd`: banner line "Schools: ..." when a boost applies.
- `tests/unit/test_school_env.gd` (new): table, stacking, text, knob overrides, branch affinity regression, resolver boost and rounding, immunity, null side.
- Backlog: `tasks/backlog/BID-100--env-school-boost-resume.md`. Resumed battles lose the boost (neutral), since setup does not re-run and weather is not saved.

Validation: editor parse check clean; `scripts/unsafe-hits.sh` no hits; gdlint clean on changed files; `tests/runner.gd` exit 0 with 0 SCRIPT ERROR; all 24 `tests/*smoke*.gd` exit 0 with 0 SCRIPT ERROR; `tests/balance_bands.gd` exit 0.

Design note: day always boosts light, so no battle is fully neutral by time. The sim stays neutral because it never calls `_apply_school_environment`.

## Documentation Updates

- `docs/agent/damage-schools.md`: new "Battlefield School Boosts (TID-755)" section (table, functions, storage, resolver, knobs, banner, sim neutrality, resume gap); tests and integrations updated.
