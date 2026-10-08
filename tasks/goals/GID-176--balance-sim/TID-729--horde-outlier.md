# TID-729: Fix the undead horde outlier (BID-095)

**Goal:** GID-176
**Type:** agent
**Status:** done
**Depends On:** TID-727

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-10-08): "fix the undead horde outlier too". The leaderless horde won 100 % one level up at any HP.

## Research Notes

- Fights lasted ~9 s with the player keeping ~78 % HP and 0 enemy casts: below enemy level 5 the minion cap is 1, and the 3-unit pack already exceeds it, so the horde never summoned.
- HP multipliers (up to 2.2×) and a tier-2/3 fight still won 100 %: its 1–2 attack units die before dealing damage. Damage and numbers were the levers.

## Plan

Leaderless packs refill to their pack size; a four-unit horde (the TID-541 test caps packs at 4); a real-time per-type attack bonus; re-measure; re-baseline.

## Changes Made

- `BattleSetup.configure_realtime`: a leaderless type's enemy-minion cap is at least its pack size.
- `EnemyRegistry`: `undead_horde` pack 3 → 4 units, `rt_attack_bonus` 2; `rt_attack_bonus()`.
- `BattleSetup.add_enemy_attack` (board, hand, deck minions; real time only).
- Result: one level up L2 30 % / L3 100 % / L4 100 % (mean ~77 %), same level 100 %; band mean 80 %, baseline rewritten.
- Test: horde cap = pack size, attack bonus applies.

## Documentation Updates

- `docs/agent/balance-sim.md`, `docs/agent/combat-model.md`, BID-095 (resolved).
