# TID-720: Enemies independent of player unlocks; casts and heavies scale by enemy level

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-716

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Decisions 2–4: enemy behaviour depends on the enemy's level, never on what the player has learned.

**Design decisions (user, 2026-10-08):**
1. **A zone has a level range, and each enemy type has a sub-range inside it.** An enemy's level is rolled or placed within its sub-range clipped to the zone. Starter camps take their level from that, not from their own authored ladder.
2. **Enemies behave the same whatever the player has learned.** No more `heavy_enabled = learned.has("kick")` or an enemy minion cap tied to `feat_minions`.
3. **Heavy blows scale with enemy level:** weaker on early enemies (or only from a level threshold up).
4. **Weaker enemies may still cast (cast-time abilities), but those hit less hard.** So when the player learns Kick, casts are already familiar.

## Research Notes

- **Remove player-unlock gating:**
  - `BattleSetup.configure_realtime`: `rt.heavy_enabled = learned.has("kick")` and `rt.set_enemy_minion_cap(CombatOnboarding.enemy_minion_cap(learned, level))`.
  - `CombatOnboarding.enemy_minion_cap` (also keyed on the player's level, `EARLY_LEVEL`).

  Replace both with enemy-level rules.
- **Heavy blows today:** `RealtimeCombat` `_heavy_timer` / `heavy_every`, `make_heavy_card`, `heavy_damage() = player max HP × tune.heavy_frac`. That is independent of enemy level. Make it scale by the enemy's level (and / or start from a threshold level). The enemy level is available as RealtimeCombat's per-side level (`_init(levels)`) and the real-time enemy level from `BattleSetup` / `enemy_level_for_tier`.
- **Enemy casts today:** `RealtimeCombat._tick_enemy` / `choose_enemy_card` / `cast_time_for` (enemy cast bars on card plays). Weak enemies keep casting but their spells hit less; scale enemy spell power by enemy level (e.g. in `SpellEffectResolver.resolve_enemy_play`, or at deck build via tier).
- **New `CombatTuning` knobs** (Momentum / Enemy group) so TID-718 can sweep them: heavy level threshold, heavy fraction per level, enemy spell power scale.
- Onboarding UI that is about the **player** (hand, Ally slots, tips) stays learned-gated. Only enemy behaviour changes.
- **Tests:** a level-1 enemy fight with and without Kick learned behaves identically (same seed → same trace); heavy damage grows with enemy level; enemy spell damage scales.
- Re-run `tools/balance_sim.gd` and record the before / after matrix in balance-sim.md.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
