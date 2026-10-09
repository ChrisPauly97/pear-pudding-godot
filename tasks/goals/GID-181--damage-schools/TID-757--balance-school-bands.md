# TID-757: Balance sim school sweeps + bands + baseline

**Goal:** GID-181
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
