# TID-771: Mono-school re-measure, tune, tighten bands

**Goal:** GID-183
**Type:** agent
**Status:** done
**Depends On:** TID-770, TID-757

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With Allies in every school, check that a mono-school deck of each school is viable and, if so, tighten the TID-757 bands from shape-matched decks toward true mono-school decks.

## Research Notes

- Tools: `tools/balance_sim.gd -- --sweep school=physical,light,dark,verdant,rift` (mono-school diagnostic added in TID-757), `game_logic/battle/BalanceBands.gd`, `tests/balance_bands.gd`, baseline `tests/data/balance_baseline.json`; docs/agent/balance-sim.md.
- Before GID-183 (TID-757 report): forest roster mono verdant 0 %, rift 3 %, physical 92 %; mountains verdant/rift 0 %.
- Tune new Ally stats first (cards are cheap to change), enemy profiles last. Report the table before/after. Regenerate baseline only for intentional moves.
- TID-757 school-matched table (default = physical; 6 fights per cell; win %; `tests/balance_bands.gd`):
  grasslands 58 | light 50 | dark 58 | verdant 58 | rift 58; forest 50 | 25 | 83 | 92 | 50;
  desert 50 | 50 | 100 | 67 | 50; scorched 50 | 42 | 50 | 50 | 50; mountains 50 | 17 | 100 | 83 | 33.
  Matchup cactus worm (weak dark / resists verdant): dark 95 vs verdant 45 (gating band +20 pp passes).
- **Dark outlier:** the dark matched deck (`tech_soul_siphon`, `tech_mana_drain`) is best in every biome, and
  is the reason the best-school-everywhere check is report-only. Desert dark 100 % also leans on cactus worm's dark weakness.
- **Noise:** 6-fight cells are ±20 pp; the (a) ±15 pp notes are partly noise. Make (a)/(c) gating
  (`BalanceBands.check_schools` / `report_schools`) once in band, with more fights if CI allows.

## Plan

1. Re-measure the TID-757 cells: matched and mono (`school=`) sweeps. Finding: the 12-fight pooled roster
   cells paired 100 % and 0 % enemies, so they measured noise; the 60-fight grid picked one informative
   enemy per biome (scout 9/7, bog hag 8/6, cactus 5/4, revenant 6/5, troll 8/6).
2. Tune the dark outlier cards first (soul_siphon, mana_drain), then Allies if verdant/rift are weak, enemy profiles last.
3. Gate (b) and (c); keep (a) report-only unless the numbers reach ±25; check mono viability.

## Changes Made

**Measured before (TID-757 pooled cells, 6 fights):** dark best everywhere, desert and mountains dark 100 %.
Mono-school decks: magic mono decks 0-30 % in most cells.

**Card changes** (`.tres` text plus `TechniqueDefs` real-time values):
- `tech_soul_siphon`: drain 3 → 2 (real time 5 → 3). Revenant dark 78 → 55 %, scout 87 → 80 %.
- `tech_overgrowth`: heal 7 → 4 (real time 8 → 4). Verdant on bog 59 → 38 %, revenant 88 → 63 %, troll 77 → 52 %.
- Tried and reverted: `tech_pyroblast` 2 → 3 (no light gain); `tech_bountiful_harvest` mana 2 → 1 (no verdant change).
- `tech_mana_drain` unchanged: the soul_siphon cut removed most of the dark lead.
- Allies untouched. Matched decks take no Allies, and mono verdant / rift on the roster cells stay 2-67 %.

**Bands** (`game_logic/battle/BalanceBands.gd`, `tests/balance_bands.gd`, `tests/unit/test_balance_bands.gd`):
- `BIOME_ROSTERS`: one informative enemy per biome (was two pooled, one of them at 0 %).
- `SCHOOL_FIGHTS` 6 → 14 (school section ~26 s, up from ~21 s).
- Band (b) matchup: GATING (unchanged, 45 vs 0 pp now, gate +20).
- Band (c) best school: GATING (`check_schools` / `best_everywhere`). Verdant leads grasslands outright; desert and forest ties mean no school is best in every biome.
- Band (a) roster: REPORT ONLY at ±25 pp (`SCHOOL_BAND`). Light trails 20-35 pp everywhere (its matched fill has a draw-only card), and desert dark / verdant sit at 100 % because of the cactus worm's profile. A profile or light fix is a separate decision.
- Mono-school decks: not viable (no magic mono deck wins 50 % in more than one cell), so not added as report-only.
- Baseline unchanged: the 16 same-level / +1 cells reproduce exactly, so `--write-baseline` was not needed.

**Before / after** (win %, default / light / dark / verdant / rift):
- grasslands 58/50/58/58/58 → 79/57/71/100/79
- forest 50/25/83/92/50 → 50/14/50/43/21
- desert 50/50/100/67/50 → 64/29/100/100/71
- scorched 50/42/50/50/50 → 43/14/64/64/29
- mountains 50/17/100/83/33 → 50/21/64/57/14
(Before: TID-757 pooled 6-fight cells. After: 14 fights on the new single cells. Both use the same seeds and the same default.)

**Validation:** editor parse clean; `unsafe-hits.sh` clean; gdlint clean on changed `.gd`; `tests/runner.gd` exit 0 with 0 SCRIPT ERROR; `tests/balance_bands.gd` PASS (CELLS 16 cells 22.6 s, school 25.7 s).

## Documentation Updates

- `docs/agent/balance-sim.md`: "School bands" rewritten with the gating table, the new roster cells, the before/after tables, the card changes, why (a) is report-only, and the mono-school numbers.
