# TID-559: Post-Fight Coaching Line

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-546, TID-550, TID-558

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Track simple per-fight real-time stats and show one most-useful tip line on the
result card at the end of a real-time fight, so a player who, say, never interrupted
a single enemy cast or sat at full mana the whole fight gets pointed at it once,
right when it's fresh.

## Research Notes

Solo PvE has two different result surfaces and neither is `BattleVictory.gd` /
`BattleDefeat._on_battle_lost` (those run reward/penalty bookkeeping *after* the
Collect/Continue button, on `GameBus.battle_won`/`battle_lost`):

- **Win**: `BattleScene._show_standard_victory()` builds the overlay directly via
  `BattleResultUI.show_victory` / `show_soulbind` / `show_victory_boss` — this is where
  the tip is added, entirely inside `BattleScene.gd` + `BattleResultUI.gd`.
- **Loss**: `GameBus.battle_lost` carries no payload, and the actual "Defeated" card
  (with Retry/Respawn/Menu) is built later, after a scene transition, in
  `autoloads/scene_manager/BattleDefeat._show_defeat_overlay()`. Since the signal is
  payload-less and the overlay is built by a different autoload, `BattleScene` stashes
  the tip on `SceneManager` (`set_pending_realtime_tip`) right before emitting
  `battle_lost`, and `BattleDefeat` reads it (`get_and_clear_pending_realtime_tip`) when
  building the overlay. **`BattleVictory.gd` (the concurrently-edited file) was not
  touched at all**; the win path never goes near it.

`SaveManager.realtime_fights` already exists (TID-552) and is already incremented once
per fight by `BattleOnboarding.begin()`. `BattleRealtime.fight_tip()` deliberately has no
side effects on it — this task only reads stats.

Damage-source attribution ("auto-attacks vs. spells") has no exact hook: `swing` events
don't carry a damage amount, and spell/skill effects don't report damage back to the
driver in a form this task can cheaply attribute. `FightStats._swing_damage` recomputes a
best-effort amount from `RealtimeCombat` (`main_hand_damage`/`offhand_damage`/attacker's
`attack`); direct spell/Strike damage isn't wired to `card_damage` at all — noted as a
gap rather than faked. `skill_uses` counts both deck-card plays (`note_player_play`) and
skill-bar presses (`note_skill_used`), which is the "skill uses" the brief asked for.

## Plan

1. Pure `game_logic/battle/FightStats.gd`: `record_*` accumulators (duration, skill uses,
   enemy casts completed, interrupts, mana-full/-empty time, auto-attack damage, potions
   used while low), `to_dict()`, and the pure static `pick_tip(data: Dictionary) -> String`
   rule (priority-ordered; unit-tested directly on plain dicts). `record_frame(dt, rt,
   events)` folds a live `RealtimeCombat` tick into the accumulators — kept on `FightStats`
   itself (not `BattleRealtime`) so `BattleRealtime.gd` stays under the 500-line lint
   ceiling that `_record_fight_stats`/`_swing_damage` would otherwise have pushed it past.
2. `BattleRealtime` owns one `fight_stats` per fight, fed from `_process` (`record_frame`)
   plus `GameBus.potion_used` and `note_skill_used`/`note_player_play` (skill uses,
   interrupts). `fight_tip()` reads the rule; no side effects.
3. `BattleResultUI.show_victory` / `show_soulbind` / `show_victory_boss` grow an optional
   `tip_text` param (default `""`, so every other call site is unaffected) rendered by a
   new shared `_add_tip_label` helper.
4. `BattleScene._show_standard_victory` computes `rt_tip` once and threads it through.
   `BattleScene._check_game_over`'s loss branch stashes it on `SceneManager`.
5. `SceneManager.set_pending_realtime_tip` / `get_and_clear_pending_realtime_tip`;
   `BattleDefeat._show_defeat_overlay` reads it and renders one label under the title.
6. Unit tests for `FightStats` (accumulators + `pick_tip` priority order); the TID-558
   Maiteln smoke scenario doubles as coverage here too (that fight ends in a loss,
   exercising the defeat-overlay tip path end-to-end with no SCRIPT ERROR).

## Changes Made

- `game_logic/battle/FightStats.gd` (+ `.uid`): stats + `record_frame` + pure `pick_tip`.
- `scenes/battle/modules/BattleRealtime.gd`: `fight_stats` field, `_on_potion_used`,
  `fight_tip()`; `note_player_play` and `note_skill_used` both record a skill use.
- `scenes/battle/modules/BattleSkillBar.gd`: skill-bar presses count toward `skill_uses`
  and successful `Kick`es toward `interrupts_landed` via `note_skill_used`.
- `scenes/battle/BattleResultUI.gd`: `tip_text` param + `_add_tip_label` on
  `show_victory`/`show_soulbind`/`show_victory_boss`.
- `scenes/battle/BattleScene.gd`: `_show_standard_victory` computes/threads `rt_tip`;
  loss branch of `_check_game_over` stashes it via `SceneManager.set_pending_realtime_tip`.
- `autoloads/SceneManager.gd`: `_pending_realtime_tip` + the get/set pair.
- `autoloads/scene_manager/BattleDefeat.gd`: reads and renders the tip in
  `_show_defeat_overlay`. **`BattleVictory.gd` was not edited.**
- `tests/unit/test_fight_stats.gd` (13 tests).

## Documentation Updates

- `docs/agent/combat-model.md`: same new subsection as TID-558 (both tasks landed in one
  pass; see that task file for the exact text).
- `CLAUDE.md`: same `BattleRealtime.gd` row update as TID-558.

## Validation

- `godot --headless --editor --quit` parse/compile check: clean.
- `bash scripts/unsafe-hits.sh`: clean.
- `gdlint` on every changed/added `.gd`: clean.
- `godot --headless --path . -s tests/runner.gd`: full suite passes, 0 SCRIPT ERROR
  (includes the new `test_fight_stats` suite).
- `tests/world_scene_smoke.gd`, `tests/realtime_battle_smoke.gd` (all three scenarios,
  including the Maiteln one ending in a loss and rendering the defeat-overlay tip),
  `tests/in_world_battle_smoke.gd`: all PASS, 0 SCRIPT ERROR.
