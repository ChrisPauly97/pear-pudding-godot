# TID-728: Critical hits for heroes and enemies

**Goal:** GID-178
**Type:** agent
**Status:** done
**Depends On:** TID-726

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-10-08): "add crits with a small % chance we can figure out by tuning in our suite / hero and enemies can crit".

## Research Notes

- Every auto-attack (hero main / off hand, Ally and enemy minion swings) goes through `RealtimeCombat._resolve_swing`, so one roll there covers both sides. Spells / techniques don't crit.
- The roll uses `rt.rng` (seeded by `BattleSetup.build`), so sim fights stay deterministic.

## Plan

1. Knobs `crit_chance`, `enemy_crit_chance`, `crit_mult`; roll in `_resolve_swing`; `crit` on swing events.
2. Presentation: bigger impact, "CRIT!" label, heavier hit feel.
3. Sim counters; sweep chances over the balance-band cells; pick defaults.

## Changes Made

- `CombatTuning`: `crit_chance` 0.05, `enemy_crit_chance` 0.05, `crit_mult` 1.5 (Auto-attack group).
- `RealtimeCombat._resolve_swing` returns the crit flag; damage × `crit_mult` (at least +1); swing events carry `crit`.
- `BalanceFight`: `crits_dealt` / `crits_taken`.
- `SwingFx.impact(..., crit)`: 1.7× slash, whiter, twice the sparks; `BattleRealtime` floats "CRIT!" and uses `hit_feel(2)`.
- Sweep (band cells, one level up mean): none 81 %, 5 %/5 % 80 %, 10 %/10 % 82.5 %, 10 %/5 % 85.6 %, 5 % × 2.0 80 %; same level 100 % in all. Picked 5 % / 5 % × 1.5 (noticeable, balance-neutral). Baseline rewritten.
- Tests: crit multiplies damage, zero chance never crits, enemies crit, crit impact is bigger. Older exact-damage fight tests now pass a no-crit tuning (their RNG is unseeded).

## Documentation Updates

- `docs/agent/combat-model.md`: "Critical hits".
