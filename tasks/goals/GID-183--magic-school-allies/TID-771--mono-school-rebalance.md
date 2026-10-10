# TID-771: Mono-school re-measure, tune, tighten bands

**Goal:** GID-183
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
