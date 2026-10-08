# TID-720: Enemies independent of player unlocks; casts and heavies scale by enemy level

**Goal:** GID-176
**Type:** agent
**Status:** done
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

1. CombatTuning Enemy knobs: `heavy_min_level`, `enemy_full_level`, `enemy_low_scale`, `enemy_two_minions_level`, plus `level_scale(L)`.
2. RealtimeCombat: `side_levels`; heavies start only at `heavy_min_level`+ (default 1 per user: heavies at every level, softened like spells) and `heavy_damage(side)` scales by level.
3. BattleSetup.configure_realtime drops `learned`; heavy blows always on (not in puzzles); enemy-minion cap by enemy level; `enemy_spell_scale`.
4. `resolve_enemy_play(..., power_scale)` softens enemy spells; scene and sim both pass it.
5. Remove `CombatOnboarding.enemy_minion_cap`; tests; balance re-run.

## Changes Made

- `CombatTuning.gd`: 4 Enemy knobs + `level_scale()`.
- `RealtimeCombat.gd`: `side_levels`, level-gated heavy start, `heavy_damage(side)` scaled, private `_level_of`.
- `BattleSetup.gd`: `configure_realtime(rt, level, type, speed, offhand, puzzle)` — no `learned`; heavies on, enemy-minion cap from `enemy_two_minions_level`; new `enemy_spell_scale(rt, side)`.
- `SpellEffectResolver.resolve_enemy_play`: `power_scale` arg (temporarily scales `spell_power`, restored after).
- `BattleRealtime.gd`, `BalanceFight.gd`: pass the scale; `CombatOnboarding.enemy_minion_cap` removed.
- `tools/balance_sim.gd`: `--enemy-offset D` (enemy level = player level + D).
- Tests: `test_realtime_combat` (heavy gating / scaling / curve), `test_battle_setup` (enemy ignores unlocks, minion cap, spell scale), `test_combat_onboarding` trimmed.

## Documentation Updates

- `docs/agent/combat-model.md`: new "Enemy strength by enemy level" section; `configure_realtime` row updated.
- `docs/agent/balance-sim.md`: TID-720 matrix.
