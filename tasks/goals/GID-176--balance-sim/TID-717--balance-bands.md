# TID-717: CI balance bands from the current baseline

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-716

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Lock in today's balance so a numbers change that moves it is noticed. User decision (2026-10-08): use the current baseline, real time only.

## Research Notes

- Run the sim on a small matrix and record the baseline. Suggested: levels {1, 5, 10, 20} × their natural enemies (`EnemyRegistry.type_for_chunk_dist` / tier ladder) + one boss, starter-style decks per level (`learned` = ladder rows up to that level).
- `tests/unit/test_balance_bands.gd`: a fast fixed-seed run (e.g. 40 fights per cell, a few seconds total) asserting win rate within baseline ± 10 % points and median duration within ± 25 %. Store the baseline in `tests/data/balance_baseline.json` with the commit it was measured at.
- Updating the baseline is a deliberate act: `balance_sim.gd --write-baseline` regenerates the JSON, and the PR shows the diff.
- Keep the test runtime ≤ 5 s; CI runs the whole suite.
- Document the bands and how to update them in balance-sim.md.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
