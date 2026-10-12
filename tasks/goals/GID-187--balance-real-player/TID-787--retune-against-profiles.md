# TID-787: Retune against profiles

**Goal:** GID-187
**Type:** agent
**Status:** done (gear share moved to TID-793)
**Depends On:** TID-779, TID-780, TID-781, TID-782, TID-784

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Re-run every band with the typical profile as the gating player and retune. Gear share target (user): gear ≈ 60 %
of a level-30 player's power, so the GID-186 hero level power shrinks to the remaining ~40 % (measure profile with
vs without gear at L30 and set `power_track` / the stat conversion knobs to hit it). Expect to give back part of GID-186's
hero level power (`power_track` 0.8, `power_from_level` 8), since gear and skills now carry some of it; per-type
`rt_hp_mult` values from GID-186 may need revisiting. Re-measure `tests/data/balance_baseline.json` once.

## Research Notes

- Knobs: `CombatTuning` (`power_track`, `power_from_level`, `enemy_hp_per_level`, `gap_hp`, `gap_damage`,
  `physical_resist_mult`, `physical_weak_mult`); per-type `EnemyRegistry` `rt_hp_mult` (GID-186 comments).
- Tooling: `tests/balance_coverage.gd --tune`, `tools/balance_sim.gd --sweep`, `tools/balance_matrix.sh`.
- Fights past ~55 s die to deck fatigue → cliffs; keep same-level medians ~30-35 s.

## Plan

Retune with the typical profile as the gating player (user 2026-10-11: "split the difference" — typical ~85 % one
level up, bare hero ~60 % as a floor), then measure the gear share.

## Changes Made

- `CombatTuning`: `gap_damage` 0.10 → 0.30, `gap_hp` 0.12 → 0.20 (the level-gap penalty; typical one level up was ~95 %).
  New knobs at neutral defaults: `stamina_hp`, `armor_per_point` (gear flat-stat conversion), `enemy_dmg_per_level`
  (`enemy_dmg_growth`, enemy swing / spell growth past `power_from_level`; 0 = off).
- `BalanceCoverage`: `world_low` / `world_high` and `bosses` fight as the typical profile
  (`BalanceProfiles.run_cell`, rotating the enemy's neutral magic types); `range` is the bare hero, a floor
  (`BARE_UP_MEAN_*` 45-80 %, no per-cell wall check). `BalanceBands` core +1 band → 45-80 % (bare hero).
- School-band cells moved to one level up (scout 8/7, bog hag 8/7, cactus 8/7, revenant 8/7, troll 7/6; matchup
  cactus 8/7) — +2 cells became walls.
- `GearDrops.expected_loadout(level, magic_type)` picks gear that fits the build (`FIT_WEIGHTS`, `fit`) within
  `FIT_WINDOW` item levels of the best; profiles use it. `BalanceProfiles.ORDER_SLACK` 15 → 25 pp. Scarab swarm
  `rt_hp_mult` 0.75 → 0.7. Baseline re-measured.
- CI coverage gains a `wounded,joiners,profiles` group.

Measured (8-16 fights per cell): world_low typical +0 100 % / +1 81 %; world_high 100 / 90 %; bosses pass (typical);
bare Chapter 1 +1 mean ~52 % (core bands) / ~60 % (range); profiles typical +1 mean ~92 %.

Not met: **gear share**. With build-fitted gear, gear supplies ~7 % of a level-30 typical player's power
(`BalanceProfiles.gear_share`, DPS × time to die) against the user's 60 %. Sweeps that move power to gear
(`stat_rating_base` 0.35, `stat_rating_growth` 0.02, `power_track` 0.2-0.3, `stat_pct_cap` 1.0) reach a 0.5-0.65
share, but fights at level 35+ then last 70-270 s and the typical player never loses: the bot's Guard / Kick cancel
heavies and casts, enemy swings deal ~5 HP/s against 250 HP, and `enemy_dmg_per_level` up to 0.1 (×4.8 at 46)
changes nothing. Gear share needs enemy threat redesigned first → TID-793.

## Documentation Updates

- `docs/agent/balance-sim.md` → Retune (TID-787).
