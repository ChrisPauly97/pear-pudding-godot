# TID-133: Update agent docs (battle-system, save-system)

**Goal:** GID-034
**Type:** agent
**Status:** done
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

1. Append "Mid-Battle State Persistence (GID-034)" section to the Pause System section in battle-system.md.
2. Add `pending_battle_state` row to the field table in save-system.md.
3. Add v14 row to the migration history table.

## Changes Made

- `docs/agent/battle-system.md`: added "Mid-Battle State Persistence (GID-034)" section after the Pause System section, covering the full serialize/save/restore/clear flow with code examples.
- `docs/agent/save-system.md`: added `pending_battle_state` field row; added v14 row to migration history.

## Documentation Updates

This task is itself the documentation update.
