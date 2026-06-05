# TID-130: Add pending_battle_state field to SaveManager

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** TID-129

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`SaveManager` already holds `pending_battle_enemy_data` to re-trigger a battle after a crash. This task adds a parallel `pending_battle_state: Dictionary` field that holds the serialized `GameState` snapshot so the battle can resume from the exact mid-battle position rather than starting fresh.

## Research Notes

**File to modify:** `autoloads/SaveManager.gd`

**Current battle fields (lines 37-38):**
```gdscript
var pending_battle_enemy_data: Dictionary = {}
var in_battle_enemy_id: String = ""
```

**Changes required:**

1. **New field** — add after `in_battle_enemy_id`:
   ```gdscript
   var pending_battle_state: Dictionary = {}
   ```

2. **new_game()** — clear it alongside `pending_battle_enemy_data` (line 150 area):
   ```gdscript
   pending_battle_state = {}
   ```

3. **save()** — add to the data dict (line 415 area):
   ```gdscript
   "pending_battle_state": pending_battle_state,
   ```

4. **load_save()** — read it back (line 363 area):
   ```gdscript
   var pbs = data.get("pending_battle_state", {})
   pending_battle_state = pbs if pbs is Dictionary else {}
   ```

5. **Migration** — bump `CURRENT_SAVE_VERSION` from 13 to 14. Add:
   ```gdscript
   static func _migrate_v13_to_v14(data: Dictionary) -> void:
       if not data.has("pending_battle_state"):
           data["pending_battle_state"] = {}
       data["version"] = 14
   ```
   And add the call in `_apply_migrations()`:
   ```gdscript
   if ver < 14:
       _migrate_v13_to_v14(data)
   ```

6. **New API helpers** — add near the existing `set_pending_battle` / `clear_pending_battle` (line 643):
   ```gdscript
   func set_pending_battle_state(state_dict: Dictionary) -> void:
       pending_battle_state = state_dict
       mark_dirty()

   func clear_pending_battle_state() -> void:
       pending_battle_state = {}
       mark_dirty()
   ```
   Check whether a `mark_dirty()` helper already exists or if the pattern is `_dirty = true` — use whatever the file uses.

**SaveManager `mark_dirty` pattern:** search the file for `_dirty = true` to find the idiom used.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
