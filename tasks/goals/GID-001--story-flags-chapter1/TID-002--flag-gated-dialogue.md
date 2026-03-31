# TID-002: Extend TownspersonNPC & WorldMap Parser for Flag-Gated Dialogue

**Goal:** GID-001
**Type:** agent
**Status:** done
**Depends On:** TID-001

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

NPC dialogue in named maps is a single static string. Story NPCs (Maiteln, Lord Farsyth, King Eldar) need to show different lines before and after the player triggers a story event. This task adds the map file syntax and the runtime support for it.

## Research Notes

**WorldMap parser** (`game_logic/world/WorldMap.gd`, `load_from_string()`):
- NPC lines currently parsed at line 296–306:
  ```
  NPC x z <dialogue text>
  ```
  Stored as `{ "id", "x", "z", "dialogue" }` dict.
- Extend to also handle `FLAG:` prefix:
  ```
  NPC x z FLAG:key_name before_text || after_text
  ```
  When the 4th token starts with `FLAG:`, extract:
  - `flag_key` = everything after `FLAG:`
  - split remainder on ` || ` → `[before_text, after_text]`
  Store as `{ "id", "x", "z", "dialogue", "flag_key", "after_dialogue" }`.
- Plain `NPC x z text` lines (no `FLAG:`) remain unchanged — `flag_key` defaults to `""`.
- `save_to_file()` at line 196 should also serialise the FLAG syntax back when `flag_key` is present.

**TownspersonNPC** (`scenes/world/entities/TownspersonNPC.gd`):
- `init_from_data(data: Dictionary)` sets `npc_data` — add extraction of `flag_key` and `after_dialogue` from the dict.
- `get_dialogue()` currently returns `npc_data.get("dialogue", "...")`.
- Extend:
  ```gdscript
  func get_dialogue() -> String:
      if _flag_key != "" and SceneManager.save_manager.get_story_flag(_flag_key):
          return _after_dialogue
      return str(npc_data.get("dialogue", "..."))
  ```
  Access SaveManager via `SceneManager.save_manager` (the pattern used throughout the codebase).

**Setting flags on interaction:**
- The flag-set for story NPCs (Maiteln → `story_intro_complete`, etc.) is handled in TID-003.
- This task only adds the *reading* side (flag-gated display). An optional `set_flag_on_interact` key in the npc dict could be set here too — discuss in Plan.

**`_extract_name()` at line 72** inspects the `dialogue` field — ensure it still works when dialogue contains `||` separators (it reads from the before-text portion, which is fine as long as extraction uses the full raw dialogue string before splitting).

## Plan

1. **WorldMap parser** (`load_from_string`): when 4th token starts with `FLAG:`, extract `flag_key` and split rest on ` || ` for before/after dialogue; store both in the NPC dict. Plain NPC lines get `flag_key: ""`.
2. **WorldMap serialiser** (`save_to_file`): when NPC dict has a non-empty `flag_key`, emit `NPC x z FLAG:key before || after`; otherwise emit the existing format.
3. **TownspersonNPC** (`init_from_data`): pull `flag_key` and `after_dialogue` from dict into instance vars. `get_dialogue()` checks `SaveManager.get_story_flag(_flag_key)` when key is set and returns the appropriate line.

## Changes Made

- `game_logic/world/WorldMap.gd` (`load_from_string`): Extended NPC parsing to detect `FLAG:key` prefix. Extracts `flag_key`, splits remainder on ` || ` for before/after text. Plain NPC lines store `flag_key: ""`, `after_dialogue: ""`.
- `game_logic/world/WorldMap.gd` (`save_to_file`): When NPC has non-empty `flag_key`, serialises as `NPC x z FLAG:key before || after`. Otherwise uses the existing format.
- `scenes/world/entities/TownspersonNPC.gd`: Added `_flag_key` and `_after_dialogue` instance vars. `init_from_data()` extracts them from the dict. `get_dialogue()` returns `_after_dialogue` when flag is set, otherwise the before-text.

## Documentation Updates

No agent doc changes required — `docs/agent/story-implementation.md` already documents this syntax and behaviour.
