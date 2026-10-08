# TID-718: Tune combat numbers to hit the targets

**Goal:** GID-176
**Type:** agent
**Status:** done
**Depends On:** TID-719, TID-720

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User targets (2026-10-08): with full HP, full mana and average play, the player beats an enemy of the same level 100% of the time and one level above about 75%. The first measurement (TID-715) is far off at the bottom: a level-1 player with only Strike lost 20/20 to `undead_basic` (dead in about 24 s), while level 5 with Allies won 20/20.

## Research Notes

**Design decisions (user, 2026-10-08):**
1. **A zone has a level range, and each enemy type has a sub-range inside it.** An enemy's level is rolled or placed within its sub-range clipped to the zone. Starter camps take their level from that, not from their own authored ladder.
2. **Enemies behave the same whatever the player has learned.** No more `heavy_enabled = learned.has("kick")` or an enemy minion cap tied to `feat_minions`.
3. **Heavy blows scale with enemy level:** weaker on early enemies (or only from a level threshold up).
4. **Weaker enemies may still cast (cast-time abilities), but those hit less hard.** So when the player learns Kick, casts are already familiar.

- With TID-719 / TID-720 done, "an enemy of level L" = the enemies whose level (from zone and type sub-range) is L. The target matrix is player level L vs enemy level L and L + 1, over the enemy types that appear at those levels.
- From TID-716, first matrix (30 fights each, `undead_basic`, ladder-learned, no gear): L1 0 % (Strike only, dead in about 24 s, at full mana the whole fight: nothing to spend it on), L2 100 %, **L3 47 %** (learning Kick sets `heavy_enabled`, and heavy blows hurt even with Kick: 41 / 71 casts kicked), L4–5 93 %, L10 100 %. Run `godot --headless --path . -s tools/balance_sim.gd -- --fights 200 --sweep level=1,2,3,4,5,10 --csv none`.
- **First, define "an enemy of level L" for the sim.** The relevant pieces:
  - zone level: `enemy_data.enemy_level`, `ZoneLevels.scaled_tier` / `scaled_hero_hp`;
  - type tier: `EnemyRegistry.get_difficulty_tier`, `type_for_chunk_dist`, `type_for_biome`;
  - starter camps: `StarterZone` levelled camp enemies (GID-141);
  - real-time enemy level-equivalent: `BattleSetup.enemy_level_for_tier`.

  Pick the enemies a level-L player actually meets, and check that `BattleSetup.build` maps `enemy_level` the way the world does.
- **Player at level L:** `learned` = UnlockLadder rows with `level_req <= L`, deck = starter + Strike + what a level-L player plausibly owns (start with the starter deck), no gear (worst case), then a gear sweep.
- **Sweep with `tools/balance_sim.gd`** before changing anything; record the matrix.
- **Levers, in order of preference:**
  1. `CombatTuning` knobs (player / enemy unarmed damage, swing speeds, mana regen, draw interval, GCD) — global and cheap.
  2. Technique real-time values (`TechniqueDefs.rt_value`).
  3. Enemy scaling (`ZoneLevels`, tier HP / attack).
  4. Onboarding caps (`CombatOnboarding`: enemy minion cap, ally cap, opening hand).

  Prefer few, global changes over per-enemy hacks. Keep changes small and re-run the matrix after each.
- `docs/agent/combat-model.md` tables must reflect any changed defaults. `test_combat_momentum` / `test_realtime_combat` may assert old numbers; update with the reason.
- Turn-based mode is out of scope (real time only).

## Plan

1. Measure the level ladder (`--enemy-offset 0|1`) and each Chapter 1 type over its range.
2. Find root causes before tuning (stat dumps, single-knob sweeps).
3. Add global level-growth / level-gap knobs; sweep in parallel; pick defaults.
4. Tests for each new rule; record the matrix; log per-type outliers.

## Changes Made

- **Bug fix:** `PlayerState.draw_opening_hand` / first `start_turn` draw never fatigue. A Strike-only deck started every fight at 20/30 HP.
- `BattleSetup.base_tier`: Chapter 1 types (`LEVEL_RANGES`) fight at tier 1; used by `enemy_tier`, `build`, `BattleRealtime` (start + join).
- `RealtimeCombat`: `_grow_hero_hp` (player `hp_per_level`), `_gap_enemy_hp` (`enemy_hp_per_level`, `gap_hp`), `_gap_scaled` on enemy swings, gap in `heavy_damage`; `_resolve_swing` takes the attacker side.
- `CombatTuning`: new `hp_per_level`, `enemy_hp_per_level`, `gap_hp`, `gap_damage`, `gap_mult()`; defaults `enemy_unarmed` 1, `enemy_low_scale` 0.3, `enemy_full_level` 15, `enemy_two_minions_level` 5.
- `BattleSetup.enemy_spell_scale` includes the gap; `resolve_enemy_play` scales up as well as down.
- `BalanceBot` policy `focus` (auto-attack the weakest enemy minion); `tools/balance_sim.gd` accepts it.
- `tools/balance_matrix.sh`: per-type matrix.
- Tests: hero HP growth, enemy gap HP, small deck unhurt (mutation-checked), gap damage, heavy scaling without gap.
- Result: same level ~100 % for every Chapter 1 type; one level up 63–100 % except `ghoul_pack` (23–40 %) → BID-095.

## Documentation Updates

- `docs/agent/balance-sim.md`: "After TID-718" matrix + what changed.
- `docs/agent/combat-model.md`: enemy-level knob table (new knobs, defaults), base tier, fatigue note.
