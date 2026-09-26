# TID-527: Battle Pacing Audit & Timing Test

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The user wants card battles to feel as fluid as WoW combat. Before changing anything, measure where time goes so later tasks have a baseline and a regression guard.

## Research Notes

- `scenes/battle/BattleScene.gd` (~1340 lines): `_battle_delay(base)` scales by `_speed_scale` (set from the
  `battle_speed` setting at ~L327; toggle in `scenes/ui/SettingsScene.gd:133`). `_action_busy` / `_ai_thinking`
  gate the End Turn button (~L871).
- AI: `ai/BasicAI.gd` `decide_turn(state, persona)` returns `Array[Callable]`; `_run_ai_turn()` (~L1015) shows an
  intent banner then waits a fixed `_battle_delay(1.5)`; `_execute_ai_actions()` runs one action at a time with
  snapshots for FX (`_fx.snapshot()`), 0.5 s tail delay.
- Scene modules under `scenes/battle/modules/` (BattleInput, BattleTargeting, BattleArena, …) — follow the
  module rules in CLAUDE.md (typed `_battle` back-ref, no bare `add_child`/`self`).
- Engage flow: `SceneManager._on_enemy_engaged` (L565) → `_enter_battle(configure, networked)` (L684) detaches the
  world into `_saved_world_scene` inside `TransitionManager.transition()` (`FADE_DURATION` 0.3 s cover + 0.3 s uncover).
  Return: `_restore_world(after)` (L725).
- Deliverable: a table in `docs/agent/battle-system.md` (engage→first-input, per-turn dead time for player/AI,
  victory→world) and a headless test that sums the fixed delays on a scripted battle so later tasks can assert
  budgets (e.g. AI turn dead time < 0.6 s at normal speed). Use `_speed_scale`-aware accounting, not wall clock.

## Plan

1. Move every fixed battle wait into a pure `BattlePacing.gd` table with budgets (no behaviour change).
2. Test: budgets, TransitionManager mirror, no literal `_battle_delay(<n>)` in BattleScene.
3. Record the baseline audit in `battle-system.md`.

## Changes Made

- New `game_logic/battle/BattlePacing.gd` (+ `.uid`): `FAST_SPEED_SCALE`, `AI_THINK`, `AI_ACTION_GAP`,
  `AI_TURN_TAIL`, `DEATH_ANIM`, `TRANSITION_HALF`, budgets, `ai_turn_dead_time()`, `engage_to_input()`.
- `BattleScene.gd`: speed scale and the three AI delays read from BattlePacing (values unchanged).
- `BattleFx.gd`: death animation duration reads `DEATH_ANIM`.
- New `tests/unit/test_battle_pacing.gd` (5 tests). Full suite exit 0, 0 SCRIPT ERRORs; gdlint + unsafe-hits clean.
- Finding: the gambit picker is a modal before every fight unless `auto_skip_gambits` is set — flagged in the
  audit for TID-528.

## Documentation Updates

`docs/agent/battle-system.md`: new "Battle Pacing" section with baseline audit table and targets.
