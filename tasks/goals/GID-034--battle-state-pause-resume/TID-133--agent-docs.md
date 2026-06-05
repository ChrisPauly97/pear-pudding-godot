# TID-133: Update agent docs (battle-system, save-system)

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** TID-132

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Two agent docs need to reflect the new mid-battle persistence system introduced by GID-034.

## Research Notes

**Files to update:**

**`docs/agent/battle-system.md`**
- Add a section "Mid-Battle State Persistence" describing:
  - `GameState.to_dict()` / `from_dict()` serialization
  - When state is saved (Return to Menu confirm, NOTIFICATION_APPLICATION_FOCUS_OUT)
  - When state is restored (BattleScene._ready on re-entry with non-empty pending_battle_state)
  - When state is cleared (battle_won, battle_lost)

**`docs/agent/save-system.md`**
- Add `pending_battle_state: Dictionary` to the field table
- Note it is version 14+ (migration v13→v14 backfills `{}`)
- Note the `set_pending_battle_state()` / `clear_pending_battle_state()` API

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
