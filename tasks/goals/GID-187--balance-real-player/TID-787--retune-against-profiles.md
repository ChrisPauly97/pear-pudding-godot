# TID-787: Retune against profiles

**Goal:** GID-187
**Type:** agent
**Status:** todo
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

## Changes Made

## Documentation Updates
