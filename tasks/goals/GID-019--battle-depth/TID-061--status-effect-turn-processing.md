# TID-061: Status Effect Turn Processing

**Goal:** GID-019
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
