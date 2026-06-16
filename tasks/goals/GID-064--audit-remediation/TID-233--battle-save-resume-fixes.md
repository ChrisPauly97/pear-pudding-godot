# TID-233: Battle save/resume fixes

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** TID-232

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battle pause/resume persistence (GID-034) has several holes: resuming a battle saved
during the AI turn soft-locks permanently, boss phase-2 and the hero power re-arm on
resume, and the AI keeps acting under the pause overlay. Depends on TID-232 because the
serialization surface changes there (bonus_mana, per-player turn counters).

## Research Notes

1. **AI-turn resume soft-lock (high).** `scenes/battle/BattleScene.gd:109-151`: a battle
   saved while it's the AI's turn (`_notification(FOCUS_OUT)` at :701-707 or
   pause→"Yes, leave" at :685 can fire mid-AI-turn) restores with
   `current_player_idx == 1`, but `_ready()` never restarts the AI (`_run_ai_turn` is
   only reachable from `_on_turn_ended`) and `_update_status` (:1032) keeps End Turn
   disabled. Fix: in `_ready` after `from_dict`, call `_run_ai_turn()` (deferred) if
   `_state.current_player_idx == 1`. Resume is a real path: WorldScene.gd:238-239
   re-engages the pending battle.

2. **AI acts under pause (high).** `BattleScene.gd:1203, 1209, 1226`: all AI-turn waits
   use `get_tree().create_timer(…, true)` (`process_always = true`) so they fire while
   `get_tree().paused == true` — the AI plays cards under the pause overlay, diverging
   from the state already saved at FOCUS_OUT. Fix: pass `false` so timers respect pause.

3. **Boss/hero-power flags not persisted (medium).** `BattleScene.gd:23-25, 511-517,
   1407-1424`: `_boss_phase2_triggered` and `_hero_power_used` are not in
   `GameState.to_dict()` — a resumed boss fight re-triggers Phase 2 (`build_deck` wipes
   the enemy's current hand/deck and redraws 4) and re-arms the once-per-battle hero
   power. Fix: persist both flags alongside the pending battle state (either in
   GameState.to_dict or in the pending_battle_state wrapper dict).

4. **No game-over check between AI actions / double battle_lost (medium).**
   `BattleScene.gd:1206-1227, 1175-1196`: after lethal, remaining AI actions still
   execute (0.6 s each) against a dead hero; on loss `battle_lost` is emitted twice
   (via `_on_turn_ended(0)`→`_check_game_over` at :1183 and again at :1213). Only
   SceneManager's `_state != State.BATTLE` guard (SceneManager.gd:311) prevents a double
   death penalty. Fix: check `is_game_over()` at the top of each AI action and make
   `_check_game_over` idempotent (`_game_over_handled` flag).

5. **Finished battle saved as pending (low).** `BattleScene.gd:701-707`: FOCUS_OUT after
   win/lose (before Collect is pressed) saves a finished battle into
   `pending_battle_state`; resume drops the player into a battle with a 0-HP hero and no
   game-over check in `_ready`. Fix: skip the pending save when `is_game_over()`, and/or
   run `_check_game_over` after restore.

6. **CardInstance id collisions on resume (low/cosmetic).**
   `game_logic/battle/CardInstance.gd:4, 37`: static `_next_id` resets on app restart;
   restored `instance_id`s can collide with new instances (phase-2 deck, weapon inject).
   `instance_id` keys the float-label/flash/shake dicts (BattleScene.gd:1738-1854) →
   wrong damage numbers. Fix: after from_dict, bump `_next_id` past the max restored id.

Verification: scripted headless test — serialize a GameState mid-AI-turn with boss
phase 2 triggered and hero power used, from_dict it, assert the AI turn completes, flags
hold, and exactly one battle_lost fires on lethal. Run full suite.

## Plan

1. Add `_make_battle_save()` helper to bundle `_state.to_dict()` with `_boss_phase2` and `_hero_power_used` keys.
2. In `_notification(FOCUS_OUT)` and pause-menu "Yes, leave": use `_make_battle_save()` and skip when `is_game_over()`.
3. In `_ready()` after `GameState.from_dict(_saved_battle)`: restore `_boss_phase2_triggered` and `_hero_power_used` from dict; call `_bump_card_next_id()`.
4. Add `_bump_card_next_id(state)` helper to scan all cards in all zones and bump `CardInstance._next_id`.
5. In `_ready()` end: if resumed mid-AI-turn, call `_run_ai_turn.call_deferred()`.
6. Fix AI timer `process_always=false` so AI doesn't act under pause.
7. Make `_check_game_over()` idempotent via `_game_over_handled` flag.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added `_make_battle_save()` helper — wraps `_state.to_dict()` with `_boss_phase2` and `_hero_power_used` flags.
  - Fixed `_notification(FOCUS_OUT)` and pause "Yes, leave" to use `_make_battle_save()` and skip when `is_game_over()`.
  - In `_ready()` resume path: restored `_boss_phase2_triggered` and `_hero_power_used` from saved dict; called `_bump_card_next_id()`.
  - Added `_bump_card_next_id(state)`: scans all card zones (hand, board, draw_deck, discard) of both players and bumps `CardInstance._next_id` past max restored numeric id.
  - Deferred `_run_ai_turn()` in `_ready()` when resuming mid-AI-turn.
  - AI timers changed to `process_always=false`.
  - `_check_game_over()` made idempotent via `_game_over_handled` flag.

## Documentation Updates

Battle save/resume behavior documented in `docs/agent/battle-system.md` (TID-285 pattern).
