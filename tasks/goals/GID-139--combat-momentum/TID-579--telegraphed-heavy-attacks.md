# TID-579: Telegraphed Heavy Enemy Attacks

**Goal:** GID-139
**Type:** agent
**Status:** todo
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Enemy casts are small unit summons, so missing a Kick costs nothing. Add an
occasional wound-up heavy hit (~25% of your HP) on the enemy cast bar that Kick
interrupts and Guard absorbs, so reacting matters.

## Research Notes

- `RealtimeCombat._tick_enemy` / `choose_enemy_card`; cast bar in `RealtimeVisuals`.
- Knobs go in `CombatTuning` (new Enemy rows).
