# TID-786: Real-time co-op scaling (2-4 heroes)

**Goal:** GID-187
**Type:** agent
**Status:** done
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

Give `RealtimeCombat` a party: co-op hero sides next to the player, enemies spreading their attacks over the
party (no RNG solo, so solo fights replay exactly), a `PlayerCaster` and `BalanceBot` per hero. `BalanceFight` cfg
`party`; the boss scales with the party. A `coop` section gates each party size against solo.

## Changes Made

- `RealtimeCombat`: `party`, `add_ally`, `is_party`, `enemy_target` (seeded random living hero; solo returns
  PLAYER without touching the rng), `siphon` (co-op heroes' mana; combo / procs / focus stay the local
  player's), `pick_target(side, opp)`, `pick_minion_target(minion, side)`, `heavy_damage(side, target)`,
  `enemy_dmg_mult`, `enemy_haste` (heavy timer and enemy GCD).
- `PlayerCaster(rt, side)` and `BalanceBot` act for any party side. `EncounterSetup.make_party_member(rt, cfg)`
  (the solo hero's setup pieces; `BattleSetup.gear_items` shared). `BalanceFight` cfg `party` (one caster + bot per
  hero, a power hook per caster, enemy spells at `enemy_target`).
- Co-op boss scaling in real time (`CoopBattleScaling.realtime_hp_mult` / `realtime_damage_mult` /
  `realtime_haste_mult`, knobs `coop_boss_hp` 1.1, `coop_boss_dmg` 0.7, `coop_boss_haste` 0.45 per extra hero). The
  turn-based `scale_boss_hp` / `scale_boss_tier` are unchanged (the tier bump made 3 heroes harder than 4 in real
  time, so it is left out there).
- `game_logic/battle/BalanceCoop.gd` (+ `test_balance_coop.gd`), section `coop`, CI group.

Measured (5 cells, 16 fights, mean win %): solo 60, party of 2 69, of 3 61, of 4 66 (gate ±25 pp of solo).
Without cadence scaling a party never lost (a Kick per hero interrupts every heavy and cast); cadence and damage
are both cliffs (haste 0.45 → 0.5 took parties of 3-4 from 95 % to 35-41 %), so the gate is on per-size means.

Not done here: the game's co-op fights are still turn-based (BID-105); these knobs apply once they move to real time.
Team battles (`setup_team_battle`) are PvP 2v2, out of scope (user, 2026-10-11).

## Documentation Updates

- `docs/agent/balance-sim.md` → Real-time co-op (TID-786); `docs/agent/multiplayer-coop.md` note.
