# TID-724: Actions per 10 s, technique recycle, Strike re-tune

**Goal:** GID-178
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-08).

## Research Notes

_TBD._

## Plan

1. Measure player actions per 10 s in the sim (baseline ~1 / 10 s at every level).
2. Techniques return to hand on a per-card cooldown (PlayerCaster) and start in the opening hand.
3. Lower Strike's real-time damage; retune enemy strength so the balance bands hold; re-baseline.

## Changes Made

- `BalanceFight`: `actions`, `actions_10s`; `BalanceStats`: `act10` column + CSV field.
- `PlayerCaster`: `_returning` queue, `_tick_returns`, `return_left`, "returned" event (card waits at the deck bottom; ignores the hand cap; a natural draw cancels it). `BattleRealtime` refreshes on "returned".
- `TechniqueDefs`: per-card `recycle` (Strike 3 s, Lance / Sweep 6 s, Kick / Guard / Mana Tap 15 s, Mend / Daze 20 s), `recycle_time()`; Strike `rt_value` 5 → 2.
- `BattleSetup.techniques_to_hand` (real time: every technique in the opening hand).
- `CombatTuning`: `tech_recycle_mult` (1.0); `enemy_unarmed` 2, `enemy_hp_per_level` 0.18, `gap_hp` 0.12, `gap_damage` 0.08.
- Result: ~3.3 actions / 10 s at L1, ~4.7–5 at L3–10; bands: same level 100 %, one level up mean 80 %; baseline rewritten.
- Tests: return after recycle, return to a full hand, early draw cancels, techniques start in hand; literal Strike values replaced by `TechniqueDefs`.

## Documentation Updates

- `docs/agent/combat-model.md`: "Combat pacing" section, recycle rule, knob table.
- `docs/agent/balance-sim.md`: "After GID-178 / TID-724" note. BID-095 updated.
