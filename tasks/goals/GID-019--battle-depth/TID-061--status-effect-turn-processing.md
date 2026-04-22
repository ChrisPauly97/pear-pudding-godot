# TID-061: Status Effect Turn Processing

**Goal:** GID-019
**Type:** agent
**Status:** done
**Depends On:** TID-060

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Once status effects are stored on ZoneState/HeroState (TID-060), they must be processed at the correct turn boundaries. This task adds processing logic to BattleScene's turn loop.

## Research Notes

- `scenes/battle/BattleScene.gd` manages the turn sequence — find `_start_turn`, `_end_turn`, or `_next_phase` methods
- Processing rules:
  - **Poison**: at the START of the affected entity's controller's turn, deal poison_value damage to the entity; decrement duration; if duration reaches 0, remove the status
  - **Armor**: consumed on damage (reduce incoming damage by armor value, decrement armor); remove when armor reaches 0 — this is passive and handled inside the damage-application function, not in turn processing
  - **Freeze**: at START of affected entity's turn, skip card-play phase (for hero) or mark minion as unable to attack; decrement duration; remove at 0
  - **Stun**: at START of affected entity's turn, skip attack phase entirely; decrement duration; remove at 0
- Process statuses for all minions on the board AND the hero at the correct boundary
- Dead minions should not be processed; check zone occupancy before processing
- Emit a signal via GameBus when a status ticks (so TID-062 UI can react) — e.g. `GameBus.emit_signal("status_ticked", entity_ref, effect_id, remaining_duration)`

## Plan

- Add `_process_start_of_turn_statuses(player_idx)` called at start of each player's turn
- Process poison: deal damage = value, decrement, clear at 0; emit `status_ticked`
- Process freeze: decrement, clear at 0; emit `status_ticked`
- Process hero stun: decrement, clear at 0; emit `status_ticked`
- Minion stun handled by `CardInstance.start_turn()` via `out_of_play`
- Armor is passive (handled in `take_damage()`)
- Call `_check_game_over()` after processing (poison may kill)

## Changes Made

- `scenes/battle/BattleScene.gd`: added `_process_start_of_turn_statuses()`, `_tick_statuses_on_card()`, `_tick_statuses_on_hero()`; modified `_on_turn_ended()` to call status processing and `_check_game_over()` before AI/player actions

## Documentation Updates

- Updated `docs/agent/battle-system.md`
