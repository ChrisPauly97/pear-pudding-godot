# TID-721: XP curve to the pacing targets + save migration

**Goal:** GID-177
**Type:** agent
**Status:** done
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

Medium complexity, but the user's targets are explicit, so I proceeded without an approval stop.
1. Derive the curve from the targets: minutes per level = 10 + 5 (L − 1); modelled XP / min = 30 × (1 + 0.1 (L − 1)).
2. A pure XpCurve that SaveManager forwards to.
3. A v47 migration preserving level and progress fraction, plus a slot-list fix and session-character repair.
4. Tests.

## Changes Made

- New `game_logic/progression/XpCurve.gd`: `minutes_for`, `xp_per_minute`, `step`, `xp_to_reach`, `level_for`, `legacy_*`, `migrate_xp`. Totals: L2 300, L3 800, L5 2 500, L10 12 260 (was 5 000), L15 32 900, L40 430 450.
- `autoloads/SaveManager.gd`:
  - `xp_for_level` / `_compute_level` forward to XpCurve;
  - head start uses `xp_to_reach(15)`;
  - the slot list's level comes from `_slot_level` (migrates a copy first, so old saves don't show a lower level);
  - `adopt_session_character` raises a session character's XP to at least its level's threshold.
- `game_logic/save/SaveMigrations.gd`: v47 `_m47_slow_xp_curve`.
- Tests: new `tests/unit/test_xp_curve.gd` (7); `test_new_game_baseline` uses `xp_for_level` instead of literals.
- Validation: full suite PASS with 0 SCRIPT ERROR; world / menu / realtime / in-world smoke tests clean; gdlint and unsafe-hits clean.
- For the user: XP_PER_MIN_L1 = 30 is a model assumption that TID-723 checks against real play. Riding (L40) is now far away (430k XP); review the high-level ladder rows separately if that matters.

## Documentation Updates

starter-zone-and-training.md (XP pacing section rewritten); save-system.md (v46 + v47 migrations).
