# TID-361: Party-scaled enemies & shared soulbound drops

**Goal:** GID-099
**Type:** agent
**Status:** done
**Depends On:** TID-359

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A joint battle is only fun if the enemy is a real threat to a whole party, and only
rewarding if everyone gets the spoils. This task adds **party-size scaling** to the
shared boss and makes the boss reward a **soulbound card to every participant**.

## Research Notes

- **Enemy data today:** `EnemyNPC.engage()` (`scenes/world/entities/EnemyNPC.gd`,
  line ~43) builds `edata` from `enemy_data` and fills `edata["enemy_deck"]` from
  `EnemyRegistry.get_deck(etype)` if absent; emits `GameBus.enemy_engaged(edata)`. Enemy
  hero HP / deck come from `EnemyData` (`data/enemies/*.tres`) via `EnemyRegistry`.
  `EnemyRegistry.get_difficulty_tier(etype)` exists (used for the difficulty pip).
- **Scaling formula (decide + document):** scale by participant count `n` (2..4):
  - boss hero HP × f(n) (e.g. base × (0.6·n + 0.4), tune so 1-equivalent ≈ base);
  - optionally a stronger deck / extra board presence / a second boss turn at high n.
  - Keep it in **pure logic** (a `CoopBattleScaling` helper or a method on the co-op
    state) so it is unit-testable and not buried in the scene.
- **Soulbinding integration:** soulbinding = "every enemy is a card" (GID-061, see
  `docs/agent` soulbinding notes / `docs/agent/multiplayer-coop.md`). On a normal win the
  defeated enemy yields a soulbound card to the victor. For co-op: award the soulbound
  card to **all** participating allies. Find where soulbound drops are granted
  (`SceneManager._on_battle_won` / soulbinding registry) and fan it out per ally —
  each ally's drop goes into **their own** GID-095 session character
  (`SaveManager.adopt_session_character` slice), via the authority + per-player intent,
  consistent with GID-096 "loot drops locally for the recipient".
- **Loss/flee semantics:** match single-player — a loss does **not** persist the boss as
  defeated (returns on reconnect, like GID-096); a win records the defeat into
  `SessionState.defeated_enemies` once (authority).
- **Other rewards:** coins/XP — decide whether each ally gets full or split rewards;
  recommend each ally gets full coin/XP reward (co-op is the draw), documented.
- **Tests:** unit-test the scaling formula (`test_coop_battle_state.gd` or a new
  `test_coop_scaling.gd`): HP/deck output for n = 1..4 monotonic and bounded.

## Plan

Implemented `CoopBattleScaling.gd` (pure static) with `scale_boss_hp` (formula:
base × (0.6·n + 0.4)) and `scale_boss_tier` (bonus = (n-1)/2, capped at 4). Applied in
`BattleScene._build_coop_pve_state`. Reward fan-out: `_build_coop_reward_payload`
computes card/rarity/stats/coins/xp once on the authority; `_finish_coop_pve` applies
locally via `_apply_coop_pve_rewards` (coins via `SaveManager.add_coins`, XP via
`SaveManager.add_xp`, card via `SaveManager.add_card_instance`). Each ally gets full
(not split) coins/XP and their own soulbound card instance. Scaling tests included in
`test_coop_battle_state.gd` (12 scaling cases).

## Changes Made

- `game_logic/battle/CoopBattleScaling.gd`: new file with `scale_boss_hp`,
  `scale_boss_tier`, `MIN_PARTY = 1`, `MAX_PARTY = 4`.
- `scenes/battle/BattleScene.gd`: `_build_coop_pve_state` applies scaling; `_coop_pve_check_game_over`,
  `_build_coop_reward_payload`, `_on_coop_battle_ended`, `_finish_coop_pve`,
  `_apply_coop_pve_rewards` implement reward fan-out.
- `tests/unit/test_coop_battle_state.gd`: scaling tests covering monotonicity,
  exact formula values, and clamping at n=0 and n=99.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: GID-099 section (scaling and rewards sub-sections).
