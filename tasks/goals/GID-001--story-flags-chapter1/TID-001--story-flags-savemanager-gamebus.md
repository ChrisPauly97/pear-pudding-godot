# TID-001: Add `story_flags` to SaveManager + `story_flag_set` to GameBus

**Goal:** GID-001
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`SaveManager` currently tracks coins, cards, position, map stack, defeated enemies, and opened chests — but has no story flag storage. `GameBus` has no signal for story flag changes. Both are needed as the foundation before any story-gated dialogue or Chapter 1 wiring can happen.

## Research Notes

**SaveManager** (`autoloads/SaveManager.gd`):
- Current save version: `CURRENT_SAVE_VERSION = 2`
- Migration chain: `_migrate_v0_to_v1`, `_migrate_v1_to_v2` — new migration `_migrate_v2_to_v3` needed
- Add field: `var story_flags: Dictionary = {}`
- Persist: add `"story_flags": story_flags` to the `data` dict in `save()`, read back in `load_save()`
- Migrate: v2→v3 just backfills `story_flags = {}` if missing
- New public API:
  ```gdscript
  func set_story_flag(key: String, value: bool = true) -> void:
      story_flags[key] = value
      _dirty = true
      GameBus.story_flag_set.emit(key)

  func get_story_flag(key: String) -> bool:
      return story_flags.get(key, false)
  ```
- Also reset `story_flags = {}` in `new_game()`

**GameBus** (`autoloads/GameBus.gd`):
- Current signals: `enemy_engaged`, `battle_won`, `battle_lost`, `map_transition_requested`, `inventory_requested`, `card_played`, `card_attacked`, `turn_ended`, `battle_ended`
- Add: `signal story_flag_set(flag: String)`

**Planned flags** (from `docs/agent/story-implementation.md`):
| Key | Set When |
|---|---|
| `story_intro_complete` | Player speaks to Maiteln in madrian |
| `chapter1_left_madrian` | Player exits madrian map |
| `chapter1_warned_farsyth` | Player speaks to Lord Farsyth in farsyth_mansion |
| `chapter1_received_letter` | Isfig encounter triggered |
| `chapter1_reached_blancogov` | Player enters blancogov |
| `chapter1_temple_council` | Player speaks to King Eldar |

## Plan

1. Add `signal story_flag_set(flag: String)` to `GameBus.gd`.
2. Add `var story_flags: Dictionary = {}` field to `SaveManager.gd`.
3. Bump `CURRENT_SAVE_VERSION` to `3` and add `_migrate_v2_to_v3` (backfills empty dict).
4. Reset `story_flags = {}` in `new_game()`.
5. Persist `story_flags` in `save()` and restore in `load_save()`.
6. Add `set_story_flag(key, value)` and `get_story_flag(key)` public methods.

## Changes Made

- `autoloads/GameBus.gd`: Added `signal story_flag_set(flag: String)` under a "Story signals" comment.
- `autoloads/SaveManager.gd`:
  - Added `var story_flags: Dictionary = {}` field.
  - Bumped `CURRENT_SAVE_VERSION` from `2` to `3`.
  - Added `_migrate_v2_to_v3()` (backfills `story_flags = {}` if absent).
  - Wired migration into `_apply_migrations()`.
  - Reset `story_flags = {}` in `new_game()`.
  - Persist `story_flags` in `save()` dict.
  - Load `story_flags` in `load_save()`.
  - Added `set_story_flag(key, value)` — sets flag, marks dirty, emits `GameBus.story_flag_set`.
  - Added `get_story_flag(key)` — returns bool from dict with `false` default.

## Documentation Updates

No agent doc changes required — `docs/agent/story-implementation.md` already describes this API correctly.
