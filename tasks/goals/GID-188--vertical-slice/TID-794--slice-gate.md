# TID-794: Slice gate + SliceRules table

**Goal:** GID-188
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One switch and one table decide what the vertical slice keeps, so the cut can't sprawl and the full game returns by
turning it off. This task gates the entry points (trainers/unlocks, main menu, battle mode); world content and the
level cap are TID-795.

## Research Notes

- Every system a player unlocks is an `UnlockLadder` row learned at a trainer (`available_at`, `pending`,
  `for_trainer`, `can_learn`). Filtering there hides features everywhere they're offered.
- HUD Mount / Phase buttons are already gated on `has_learned`, so the ladder gate covers them; co-op HUD only
  exists in a session, which the menu now hides.
- `SaveManager.battle_mode()` is the single read point for the battle mode.
- Smoke tests run outside `tests/runner.gd`, so they see the shipped setting.

## Plan

`game_logic/SliceRules.gd` (setting key, `LEVEL_CAP`, `LADDER`, `MENU`, `BATTLE_MODE`, test `override`), project
setting on, gates in UnlockLadder / MenuScene / SaveManager.battle_mode, runner forces it off, slice tests.

## Changes Made

- `game_logic/SliceRules.gd` (new): the table + `active()`, `allows_ladder`, `allows_menu`, `battle_mode`.
- `project.godot`: `[pear_pudding] slice_mode=true`.
- `UnlockLadder`: `available_at` / `pending` / `for_trainer` / `can_learn` skip out-of-slice rows.
- `MenuScene`: Co-op, Achievements, Map Editor hidden in the slice.
- `SaveManager.battle_mode()`: real time in the slice.
- `tests/runner.gd`: `SliceRules.override = 0`. `tests/battle_input_flow_smoke.gd`: same (turn-based input).
- Settings "Full Game (beyond the demo)" toggle: per-device opt-out of the slice (`SliceRules.full_game_enabled` /
  `set_full_game`, `user://full_game.cfg`, so the menu can read it before a save loads); menu re-applies on close.
- `tests/unit/test_slice_rules.gd` (9 tests). Full suite 3643 pass; smoke tests green except the known
  `inventory_tiles_smoke` failures (BID-106, unchanged).

## Documentation Updates

- `docs/agent/vertical-slice.md` (new), CLAUDE.md section + docs table row.
