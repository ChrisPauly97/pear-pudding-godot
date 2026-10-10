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

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
