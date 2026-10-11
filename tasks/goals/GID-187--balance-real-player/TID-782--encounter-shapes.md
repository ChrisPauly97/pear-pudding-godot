# TID-782: Encounter shapes: joiners, boss phase 2, boss ranges

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Sim a second enemy joining mid-fight (team battle), boss phase 2 (deck + school profile swap) and every boss across
its whole level range, not just its first level. Bands: a joiner fight is harder but winnable; bosses hit a target
band over their range.

## Research Notes

- Joiner: `BattleRealtime.join_enemy` (GID-186 fixed its level), `RealtimeCombat.add_enemy`; move setup into
  `BattleSetup` so the sim can call it at time t.
- Phase 2: `EnemyRegistry.get_phase2_deck`, `get_school_profile(type, 2)` (`schools_phase2`); where BattleScene
  triggers the turn (grep `phase2`).
- `BalanceCoverage.BOSSES` / `measure_bosses` currently one level each.

## Plan

## Changes Made

## Documentation Updates
