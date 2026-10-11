# TID-793: Enemy threat scaling and the 60 % gear share

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-787

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User target (2026-10-11): gear ≈ 60 % of a level-30 player's power. TID-787 measured ~7 % with build-fitted gear.
Moving power from levels to gear (cheaper ratings, lower `power_track`) reaches the share but makes high-level
fights 70-270 s and unlosable: enemy threat does not scale with the hero's growth.

## Research Notes

- Level-46 frost wendigo vs a typical light player (TID-787 probe): enemy 1091 HP; hero 250 HP took 302 damage in
  65 s and won (leech). Bot used Guard ×10 and Kick ×10 — heavies and casts are mostly nullified, swings are tiny.
- `enemy_dmg_per_level` (swings + spells past `power_from_level`) has no effect up to 0.1. Threat must come from
  sources the bot can't fully cancel: unblockable / partial heavies, enemy unarmed growth, minion attack growth with
  level, or Guard / Kick costs and cooldowns that scale.
- Knobs ready: `stat_rating_base`, `stat_rating_growth`, `stat_pct_cap`, `stamina_hp`, `armor_per_point`,
  `power_track`, `enemy_dmg_per_level`. Measurement: `BalanceProfiles.gear_share(level, enemy)`; fight length
  matters (same-level median 30-60 s).
- Also: magic types are uneven with full builds (rift strongest, dark weakest — TID-787 probes) and the casual bot
  loses packs (BID-107).

## Plan

## Changes Made

## Documentation Updates
