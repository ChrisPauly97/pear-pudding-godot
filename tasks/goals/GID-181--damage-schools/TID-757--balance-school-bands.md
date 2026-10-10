# TID-757: Balance sim school sweeps + bands + baseline

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-750, TID-754, TID-755

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Guard the design numerically: schools must matter without one school dominating, and same-level fights stay fair.

## Research Notes

- Tools: `tools/balance_sim.gd` (`--fights --sweep`), `game_logic/battle/BalanceFight.gd` `run(cfg, policy)` L26, `BalanceBot.gd`, `BalanceBands.gd` (`measure` L45, `check` L62, baseline `tests/data/balance_baseline.json`), CI test `tests/balance_bands.gd`. Doc: docs/agent/balance-sim.md.
- Add a sweep key `school=physical,light,dark,verdant,rift` building a mono-school deck (cfg `deck`) from CardRegistry by magic_type.
- New bands: (a) mono-school deck vs each biome's mixed roster within ±X% of the mixed deck; (b) right school vs a resisting enemy ≥ +Y pp win rate over wrong school; (c) no school best in every biome. Existing bands (same level ≥97%, +1 level 65–85%) must still pass.
- Re-run with `--write-baseline` and commit the JSON once numbers are intentional.

## Plan

1. `tools/balance_sim.gd`: `--sweep school=…` (pure mono-school diagnostic, `BattleSetup.school_deck`) and `--sweep matched=…` (shape-matched deck).
2. Shape-matched deck (`BattleSetup.school_matched_deck`): default deck with two Allies swapped for the school's cards. Physical is the default.
3. `BalanceBands`: roster cells per biome, matchup cell, `measure_schools`, gating `check_schools` (matchup only), report-only `report_schools`.
4. `tests/balance_bands.gd` prints the table and the report; unit tests; docs; baseline unchanged (no profile or combat change).

## Changes Made

- `game_logic/battle/BattleSetup.gd`: `school_deck` (mono diagnostic), `school_matched_deck`, `MATCHED_SWAP` = 2, helpers `_card_school` / `_school_cards`.
- `tools/balance_sim.gd`: `school=` and `matched=` sweep keys.
- `game_logic/battle/BalanceBands.gd`: `BIOME_ROSTERS` (5 biomes, 9 cells), `MATCHUPS` (cactus worm 6 vs 4), `measure_schools` (physical reuses default), `check_schools` (GATING: matchup ≥ +20 pp), `report_schools` (REPORT ONLY: (a) ±15 pp per biome, (c) best everywhere).
- `tests/balance_bands.gd`: prints the school table, matchup line, report-only notes; gate = matchup.
- `tests/unit/test_balance_bands.gd`: matchup gating, roster notes are report-only, matched deck shape.
- Baseline `tests/data/balance_baseline.json` unchanged (no profile or combat change).

Measured (6 fights per cell, win %, default = physical): see `docs/agent/balance-sim.md` "School bands".
Matchup cactus worm weak dark 95 vs resisted verdant 45 (+50 pp, passes +20 pp).
(a) notes: forest light/dark/verdant, desert dark/verdant, mountains light/dark/verdant/rift. (c): dark best in every biome.
Decision (coordinator): (b) gates CI; (a) and (c) report only, tightened in GID-183 / TID-771 (dark outlier: soul_siphon, mana_drain).

Validation: parse clean; gdlint clean on changed files; unsafe-hits clean for these files; `tests/runner.gd` exit 0, 0 SCRIPT ERROR (3449 passed); `tests/balance_bands.gd` RESULT PASS, school section 19.9 s (target ≤ 20 s).

## Documentation Updates

- `docs/agent/balance-sim.md`: "School bands (TID-757)" section (matched decks, sweep keys, gating vs report-only, measured table, gaps).
- `docs/agent/damage-schools.md`: balance-sim line replaced with the TID-757 summary.
- `tasks/goals/GID-183--magic-school-allies/TID-771--mono-school-rebalance.md`: research note with the matched table, dark outlier and "make (a)/(c) gating once in band".
