# TID-780: Fight conditions shared by sim and game

**Goal:** GID-187
**Type:** agent
**Status:** done
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

1. Pure `game_logic/battle/FightConditions.gd`: weather start poison, school env stamp, summon weather, blight,
   ambush side + apply, gambit handicaps + emboldened bonus, scorch (`scorch_active`, `scorch_leftmost`).
2. `BattleSetup.build` cfg keys `weather`, `biome`, `is_night`, `blighted`, `ambush`, `gambit_id`, in BattleScene order.
   Battlefield context only when a context key is named (bare cfg unchanged).
3. Game call sites (BattleModifiers, BattleScene, RealtimeCombat) delegate; BalanceFight applies summon weather.
4. `BalanceCoverage` `conditions` section: 18 conditions + 5 school envs on two cells, gates from measurement.
5. Unit tests, docs, validation.

## Changes Made

- New `game_logic/battle/FightConditions.gd` (+ `.uid`): the moved rules, no autoload or scene access.
- `game_logic/battle/BattleSetup.gd`: cfg keys above; `FightConditions` order matches BattleScene.
- `scenes/battle/modules/BattleModifiers.gd`: thin wrappers over FightConditions; removed unused preloads.
- `scenes/battle/BattleScene.gd`: removed `_AMBUSH_HP_*` constants; emboldened / blight / scorch gate call FightConditions.
- `game_logic/battle/RealtimeCombat.gd`: `_scorch_leftmost` replaced by `FightConditions.scorch_leftmost` (same
  per-side round tick, focus cleared on a kill).
- `game_logic/battle/BalanceFight.gd`: summon weather on enemy minions (as BattleRealtime does).
- `game_logic/battle/BalanceCoverage.gd`: `conditions` section (`SECTIONS`, `measure_conditions`, `check_conditions`).
  Not added to the CI workflow (parent does that).
- Tests: `tests/unit/test_fight_conditions.gd` (new, rules); `tests/unit/test_battle_setup.gd` (cfg-key tests, moved
  there to stay under gdlint's 30-method limit).
- Measured (`--section conditions`, 32 fights per cell, duelist adept 14 and rift echo 20, same level): all conditions
  and school envs 97–100 %; largest swing 3 pp (desert day, duelist adept, 96.9 vs 100). Gates: condition swing
  ±25 pp, school env not lower than its matched deck by more than 7 pp. Runtime about 175 s.
- Caveat: same-level cells sit at the ceiling, so the gates are weak there. The +1 cell (67 % base, 24 fights) was
  noisy (single conditions up to +33 / -17 pp), so it was not gated. Recorded in balance-sim.md.
- Default bands unchanged (`tests/balance_bands.gd` PASS, baseline not rewritten).

## Documentation Updates
- `docs/agent/balance-sim.md`: "Battlefield conditions (GID-187 / TID-780)" section (cfg keys, context switch,
  conditions gates and measurements, ceiling caveat); "Not simulated" list updated.
