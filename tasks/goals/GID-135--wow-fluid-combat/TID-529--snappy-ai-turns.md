# TID-529: Snappy Enemy Turns

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-527

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Enemy turns currently wait a fixed 1.5 s and then resolve each action serially with delays. WoW-fluid means the enemy acts quickly and the player is rarely waiting.

## Research Notes

- `scenes/battle/BattleScene.gd` (~1340 lines): `_battle_delay(base)` scales by `_speed_scale` (set from the
  `battle_speed` setting at ~L327; toggle in `scenes/ui/SettingsScene.gd:133`). `_action_busy` / `_ai_thinking`
  gate the End Turn button (~L871).
- AI: `ai/BasicAI.gd` `decide_turn(state, persona)` returns `Array[Callable]`; `_run_ai_turn()` (~L1015) shows an
  intent banner then waits a fixed `_battle_delay(1.5)`; `_execute_ai_actions()` runs one action at a time with
  snapshots for FX (`_fx.snapshot()`), 0.5 s tail delay.
- Scene modules under `scenes/battle/modules/` (BattleInput, BattleTargeting, BattleArena, …) — follow the
  module rules in CLAUDE.md (typed `_battle` back-ref, no bare `add_child`/`self`).
- Target: intent banner overlaps the first action (short ~0.3 s beat), actions pipeline (next starts when previous
  hit lands, not after full FX tail), remove the 0.5 s tail. Consider making `fast` the default `battle_speed`.
- Must keep `_state` authoritative ordering; only visual overlap. Co-op boss path (BID-027 index logic) must still work.
- Tests: `tests/unit/test_basic_ai.gd`, `test_ai_personas.gd`, battle smoke tests; extend TID-527 budget test.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
