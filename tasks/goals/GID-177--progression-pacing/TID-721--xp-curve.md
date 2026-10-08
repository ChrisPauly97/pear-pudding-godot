# TID-721: XP curve to the pacing targets + save migration

**Goal:** GID-177
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make levelling follow the targets above.

**Pacing targets (user, 2026-10-08):**
- Levelling is much slower; there's no rush to level 10.
- Level 1 takes about **10 minutes** of play, and each level after takes longer ("graduating up"). Working model: +5 min per level, so L1 10, L2 15, L3 20 … L9 50 min, about 4.5 h to level 10. Confirm the step when the first numbers are in.
- From level 3 on, a level takes **a few quests** (about 3–4) plus the kills along the way.

## Research Notes

- **Today:** `SaveManager.xp_for_level(L) = L² × 50` total XP (L2 200, L3 450, L5 1250, L10 5000); `_compute_level(xp)` derives the level from XP. Kill XP is `EnemyRegistry.get_xp_reward` (undead_basic 20, horde 35, ghoul_pack 50, elite 80) × `ZoneLevels.scaled_xp` (con colour). Quest XP is `SideQuests` rewards (150–560 for L1–9).
- **Model XP per minute** from real pacing: fight length from `tools/balance_sim.gd` (about 15–25 s) + travel / respawn (`StarterZone.CAMP_RESPAWN_S` 45 s) → kills per minute; quest XP per minute from the chain. Derive the per-level XP so that L1 ≈ 10 min, +5 min / level, and from L3 each level ≈ 3–4 quests + kills.
- Put the curve in one pure table (e.g. `game_logic/progression/XpCurve.gd`: `xp_to_reach(level)`, `level_for(xp)`), used by SaveManager, tests and the sim. Keep `xp_for_level` as a forwarder for callers.
- **Migration** (`SaveMigrations`, bump CURRENT_VERSION): existing saves keep their level. Convert XP to the same fraction of the way through that level on the new curve; `skill_points` stays clamped to level − 1.
- Session characters (`SessionState`) store XP too; check they derive the level the same way.
- Tests: the curve is monotonic; level_for(xp_to_reach(L)) == L; a migration keeps the level; the time model gives L1 ≈ 10 min (± 20 %).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
