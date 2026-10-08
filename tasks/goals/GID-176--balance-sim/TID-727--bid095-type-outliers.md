# TID-727: Fix the ghoul pack and scout outliers (BID-095)

**Goal:** GID-176
**Type:** agent
**Status:** done
**Depends On:** TID-718, GID-178/TID-724

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-10-08): "fix the ghoul pack and scout outliers in BID-095". After GID-178 the scout was ~30–50 % one level up (too hard) and the ghoul pack 87–100 % (too easy).

## Research Notes

- The level gap (`gap_hp`) only scaled the enemy **hero**; pack units on the board never grew, so packs fell behind as levels rose.
- The scout's threat is heavies + swings (few casts); its hero scales fully with level, so it ran hot.
- Win rates are cliffy (a fixed bot), so the per-type target is the **mean** over the type's level range.

## Plan

1. Scale pack units with the same level / gap multiplier as the hero.
2. Per-type real-time HP multiplier (`rt_hp_mult`) for remaining outliers.
3. Re-run `tools/balance_matrix.sh`, re-baseline the bands.

## Changes Made

- `RealtimeCombat._gap_enemy_hp`: board units of the enemy side scale with the hero's multiplier.
- `EnemyRegistry.rt_hp_mult()` + `rt_hp_mult` on `martarquas_scout` 0.85, `imbued_stag` 0.9, `ghoul_pack` 0.95.
- `BattleSetup.scale_enemy_hp` (in `configure_realtime`); `BattleRealtime.join_enemy` applies it too.
- `CombatTuning` `gap_damage` 0.08 → 0.10.
- Tests: pack units scale with the gap, `rt_hp_mult` applies. Baseline rewritten (mean one level up 82 %).
- Result (mean one level up): ghoul pack 80 %, scout ~82 %; every type 68–91 % except the leaderless horde (BID-095 stays open for it).

## Documentation Updates

- `docs/agent/balance-sim.md` ("After TID-727"), `docs/agent/combat-model.md` (knob table, per-type note), BID-095.
