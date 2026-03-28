# TID-001: Add `story_flags` to SaveManager + `story_flag_set` to GameBus

**Goal:** GID-001
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
