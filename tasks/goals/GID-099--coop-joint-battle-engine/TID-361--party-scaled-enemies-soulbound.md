# TID-361: Party-scaled enemies & shared soulbound drops

**Goal:** GID-099
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
