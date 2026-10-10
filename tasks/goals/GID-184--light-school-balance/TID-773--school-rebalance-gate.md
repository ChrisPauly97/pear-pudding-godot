# TID-773: Re-measure schools, tune, gate band (a)

**Goal:** GID-184
**Type:** agent
**Status:** done
**Depends On:** TID-772

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md. BID-101: light matched fill is pyroblast + blazing_draw; blazing_draw deals no damage.

## Research Notes

- Resolver: `scenes/battle/SpellEffectResolver.gd` (`deal_damage_single` arm, `ENEMY_TARGETED_EFFECTS`). Hero-target checks
  for `deal_damage_single` are hard-coded in `BattleTargeting.gd` (94, 163), `BattleInput.gd` (153), `BalanceBot.gd` (140).
- Labels `game_logic/battle/SpellEffectLabels.gd`; skill mods `SkillMods.DAMAGE_EFFECTS`; real-time power `TechniqueDefs` (`rt_value`).
- Builder hits come from `PlayerCaster._after_technique` (dealt > 0), so any damaging effect is a builder.
- Bands: `BalanceBands.check_schools` / `report_schools`, `SCHOOL_BAND` 25, `SCHOOL_FIGHTS` 14. TID-771 after-table
  (default/light/dark/verdant/rift): grass 79/57/71/100/79, forest 50/14/50/43/21, desert 64/29/100/100/71,
  scorched 43/14/64/64/29, mountains 50/21/64/57/14.

## Plan

1. Re-measure with `tests/balance_bands.gd`; tune Blazing Draw real-time numbers.
2. Rift has the same draw-only fill shape: buff Mana Surge real-time hit.
3. Make band (a) gating for neutral matchups (profiled schools are band (b)).

## Changes Made

- `TechniqueDefs`: Blazing Draw rt 3 / recycle 12 s (rt 6 / 8 s overshot: light 93–100 % everywhere); Mana Surge rt 2 → 4 (card + skill text updated).
- `BalanceBands.gd`: `measure_schools` records `profiles` (schools each biome enemy resists / is weak / immune to); new gating `neutral_school_fails` inside `check_schools`; `report_schools` kept as notes.
- `tests/balance_bands.gd` messages; `tests/unit/test_balance_bands.gd`: profiles in the synthetic measure, `test_school_roster_band_gates_neutral_matchups_only`.
- Result: all cells in band; table in balance-sim.md. Mono decks still uneven → BID-102. BID-101 archived.
- Validation: runner 3460 / 0 / 0 SCRIPT ERROR; `tests/balance_bands.gd` PASS.

## Documentation Updates

- `docs/agent/balance-sim.md`: bands table, GID-184 measurements, mono re-check.
