# TID-530: Input Flow — Spell Queue & One-Tap Targeting

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-546

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

**Refocused (2026-09-26) for real-time combat:** WoW-style spell queue (a card tapped in the last ~0.4 s of
the GCD plays when it ends), one-tap targeting for spells, keyboard number keys for hand slots. Auto End Turn is
moot in real time. Hook: `BattleRealtime.on_cooldown()` / `_can_local_act()`.

## Plan

1. One-tap spells: `BattleTargeting.auto_target` — one legal target casts at once; real time
   uses the focus target.
2. New `BattleShortcuts` module (BattleInput is near the line cap): number keys for hand cards
   (after the skill keys in real time), Space = end turn.
3. Auto end turn setting (default on) for solo turn-based fights with a 1.2 s grace.
4. Spell queue already shipped (`in_queue_window`).

## Changes Made

- New `scenes/battle/modules/BattleShortcuts.gd` (+ uid); `BattleScene` (module, one call at the end
  of `_refresh_all`); `BattleTargeting.auto_target`; `BattleInput` (uses it); `SettingsScene`
  (Auto End Turn toggle).
- New `tests/battle_input_flow_smoke.gd`, added to CI's scene smoke list (verified to fail when
  `has_move()` always reports a move).

## Documentation Updates

- `battle-system.md` → Input Flow.
