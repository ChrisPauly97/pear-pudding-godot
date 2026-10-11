# TID-786: Real-time co-op scaling (2-4 heroes)

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Turn-based combat is deprecated (user, 2026-10-11), so co-op is measured in real time: extend `RealtimeCombat` /
`BalanceFight` to 2-4 player sides (each with its own `BalanceBot`) against a co-op boss with the game's scaling.
The game's co-op fights are still turn-based today; moving them to real time is BID-105. Band: a party of N
clears a same-level boss at about the solo rate (± a band), so co-op is neither a carry nor a wall; also team
battles (`setup_team_battle`) if PvE.

## Research Notes

- `GameState.setup_coop_battle(n_allies, ally_setup, boss_setup)` (l.384); `CoopBattleScaling.scale_boss_hp(base, n)`
  / `scale_boss_tier(base_tier, n)`; `BattleNet.gd` ~l.1072 builds the co-op boss.
- Co-op PvE AI turn smoke: `tests/coop_pve_ai_turn_smoke.gd`.
- PvP is out of scope (user, 2026-10-11).

## Plan

## Changes Made

## Documentation Updates
