# TID-779: Progression rewards matter (gear / skills / upgrades bands)

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Paired cells (same seeds, like the GID-186 school matrix): profile with vs without one reward axis — a weapon
upgrade tier, a skill build, card upgrades, a school affix, a companion. Gate: each axis raises win rate by a
minimum; no single axis exceeds a cap (no must-have item). Also: within a magic type, no skill build dominates.

## Research Notes

- Paired-cell pattern and fixed seeds: `BalanceCoverage.measure_schools` / `check_schools`.
- Companions: `BattleModifiers._apply_companion_battle_start` / `_apply_companion_turn_start` (extra_mana,
  hero_armor, draw_card) — not in `BattleSetup`; move the real-time-relevant part there (sim + game share it).
- Known outlier: BID-103 (fourth technique slot is a large power step) belongs here.

## Plan

## Changes Made

## Documentation Updates
