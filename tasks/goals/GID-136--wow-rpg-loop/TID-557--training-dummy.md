# TID-557: Training Dummy

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** TID-537, TID-550

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A training dummy stands in town next to the skill trainer (TID-537). Interacting
starts a real-time practice fight against a dummy enemy that never attacks or
casts, with lots of HP, no rewards, no defeat consequences, not counted toward
`CombatOnboarding.realtime_fights`, and not recorded as defeated. The player can
leave any time.

## Research Notes

- Real-time enemy heroes auto-attack **by default** even with an empty deck:
  `RealtimeCombat.main_hand_damage()` uses `hero.attack + unarmed[side]`, and
  `unarmed[ENEMY]` comes from `tune.get_i("enemy_unarmed")` (default 2). An
  empty deck alone does not make an enemy passive — a real `passive` flag is
  needed.
- `EnemyRegistry._ensure_loaded()` is the single source of enemy battle data
  (no `.tres` enemy resources — see CLAUDE.md "Save Fields").
- `GameBus.duel_requested(enemy_data, wager)` → `SceneManager._on_duel_requested`
  already skips the gambit picker, and `_on_duel_won`/`_on_duel_lost` only touch
  `defeated_duelists` / grant a champion card when `duel_npc_id` /
  `champion_reward_card` are non-empty — an empty `duel_npc_id` gives a
  consequence-free fight for free, reusing the existing duelist plumbing
  instead of a new entry point.
- `BattlePauseUI.gd`'s "Flee Battle" button is already unconditional in every
  battle kind (emits `GameBus.battle_fled`, which `SceneManager._on_battle_fled`
  handles with no penalty) — no dummy-specific "Leave" button was needed.
- `BattleOnboarding.begin()` unconditionally incremented
  `SaveManager.realtime_fights` (the new-player control ramp, TID-552/553) —
  needed a way to skip that for a fight that shouldn't count.

## Plan

1. `RealtimeCombat`: add `_passive_sides: Dictionary`, `set_passive(side)`,
   `is_passive(side)`; skip `_tick_enemy` and `_tick_hero` for a passive side
   in `advance()`/`_tick_swings()`, independent of deck/attack data.
2. `EnemyRegistry`: add a `"training_dummy"` entry (`is_boss: true`,
   `boss_hp: 500`, empty `deck`, `coin_reward: 0`, `passive: true`) and an
   `is_passive(type_id)` reader.
3. `BattleRealtime.maybe_start()`: call `rt.set_passive(RealtimeCombat.ENEMY)`
   when `EnemyRegistry.is_passive(enemy_type)`.
4. `BattleOnboarding.begin(count: bool = true)`: only increments/dirties
   `realtime_fights` when `count` is true; `BattleRealtime` passes
   `not is_passive` so the dummy never advances (or "spends") the ramp.
5. `NpcInteractions.gd`: `"training_dummy"` dispatch → confirm prompt →
   `GameBus.duel_requested({"enemy_type": "training_dummy", ...}, 0)` with an
   empty `duel_npc_id`/`champion_reward_card`.
6. Place `training_dummy_madrian` next to the trainer NPC in Madrian.

## Changes Made

Implemented together with TID-537 (same commit — the passive-enemy plumbing
and the trainer/dummy NPCs were built and validated as one unit; this task
file documents the training-dummy-specific slice):

- `game_logic/battle/RealtimeCombat.gd`: `_passive_sides`, `set_passive()`,
  `is_passive()`; `advance()`'s enemy-cast loop and `_tick_swings()`'s
  per-side loop both skip a passive side.
- `autoloads/EnemyRegistry.gd`: `"training_dummy"` entry + `is_passive()`.
- `scenes/battle/modules/BattleRealtime.gd`: `maybe_start()` calls
  `rt.set_passive(RealtimeCombat.ENEMY)` for a passive enemy type, and passes
  `not is_passive(enemy_type)` into `onboarding.begin(count)`.
- `scenes/battle/modules/BattleOnboarding.gd`: `begin(count: bool = true)` —
  `realtime_fights` only advances when `count` is true.
- `scenes/world/modules/NpcInteractions.gd`: `"training_dummy"` dispatch →
  `_offer_training_dummy_fight()` (confirm prompt, then
  `GameBus.duel_requested` with `enemy_type: "training_dummy"`, `is_boss:
  true`, `boss_hp` from `EnemyRegistry.get_boss_hp()`, empty `duel_npc_id`/
  `champion_reward_card`, wager 0).
- `scenes/world/WorldScene.gd`: `_NPC_PROMPT_LABELS["training_dummy"] =
  "PRACTICE"`.
- `assets/maps/madrian.tres`: `training_dummy_madrian` NPC (tile 81,44), next
  to `trainer_madrian`.
- No new "Leave" UI: the existing pause-menu "Flee Battle" button already
  works unconditionally for every battle kind, including this one.
- No new reward/defeat-record path: reusing `GameBus.duel_requested` with an
  empty `duel_npc_id` means `SceneManager._on_duel_won`/`_on_duel_lost` never
  touch `defeated_duelists` or grant a card for this fight.

## Documentation Updates

- `docs/agent/enemies-and-npcs.md`: "Skill Trainer & Training Dummy" section
  (shared with TID-537) documents the `"training_dummy"` npc_type, its
  `EnemyRegistry` entry, and the passive-enemy mechanism end to end.
- `docs/agent/combat-model.md`: "Learning abilities & the loadout" subsection
  under "Skill bar — fixed abilities" mentions the training dummy and links
  here.
