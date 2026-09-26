# TID-530: Input Flow — Queued Taps, One-Tap Attack, Auto End Turn

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-527

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Player input is locked while `_action_busy`; attacks need multi-step selection; the player must press End Turn even when nothing is playable.

## Research Notes

- `scenes/battle/BattleScene.gd` (~1340 lines): `_battle_delay(base)` scales by `_speed_scale` (set from the
  `battle_speed` setting at ~L327; toggle in `scenes/ui/SettingsScene.gd:133`). `_action_busy` / `_ai_thinking`
  gate the End Turn button (~L871).
- AI: `ai/BasicAI.gd` `decide_turn(state, persona)` returns `Array[Callable]`; `_run_ai_turn()` (~L1015) shows an
  intent banner then waits a fixed `_battle_delay(1.5)`; `_execute_ai_actions()` runs one action at a time with
  snapshots for FX (`_fx.snapshot()`), 0.5 s tail delay.
- Scene modules under `scenes/battle/modules/` (BattleInput, BattleTargeting, BattleArena, …) — follow the
  module rules in CLAUDE.md (typed `_battle` back-ref, no bare `add_child`/`self`).
- Input lives in `scenes/battle/modules/BattleInput.gd` (hand/board/enemy taps, cast confirm, attacks) and
  `BattleTargeting.gd`.
- Ideas: buffer one input during animations and apply it when `_action_busy` clears; tap a ready minion → auto-attack
  the only legal target (or the enemy hero if no taunt/ward blockers) with a long-press for manual targeting;
  optional setting "auto end turn when no legal plays" (on by default, with a short grace window + cancel).
- Keep keyboard parity (CLAUDE.md mobile/desktop parity): e.g. Space = end turn, number keys = play card.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
