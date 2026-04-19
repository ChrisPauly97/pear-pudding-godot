# TID-065: Wire Flag-Check Logic into TownspersonNPC

**Goal:** GID-020
**Type:** agent
**Status:** done
**Depends On:** TID-063, TID-064

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With MapNpc now storing flag_key and dialogue_before/after (TID-064) and the human having authored the dialogue text (TID-063), this task wires the flag-check logic into TownspersonNPC so it returns the correct line based on SaveManager.story_flags.

## Research Notes

- `scenes/world/entities/TownspersonNPC.gd` — find `get_dialogue()` method; currently returns a static string
- `autoloads/SaveManager.gd` — story flags live in `SaveManager.story_flags: Dictionary`; check `SaveManager.story_flags.get(flag_key, false)`
- The NPC is initialized from a `MapNpc` resource (passed in at spawn time) — the NPC node should store the MapNpc resource reference or its individual fields
- Logic: if flag_key is empty → return dialogue (static, no gating); if flag_key is set and `SaveManager.story_flags.get(flag_key, false)` is true → return dialogue_after; else → return dialogue_before
- If dialogue_after is empty and the flag IS set → return an empty string (NPC has nothing to say post-flag); don't crash
- Update `scenes/world/entities/TownspersonNPC.gd` only — do not change WorldScene NPC spawning more than needed to pass MapNpc fields through

## Plan

Implementation was already complete before this task ran. Verified:
- `scenes/world/entities/TownspersonNPC.gd:91–94` — `get_dialogue()` checks `SaveManager.get_story_flag(_flag_key)` and returns `_after_dialogue` when true, else `npc_data["dialogue"]`
- `init_from_data()` at line 59 populates `_flag_key` and `_after_dialogue` from the dict passed by ChunkRenderer
- WorldScene.gd:1085–1098 calls `get_dialogue()` before setting the flag, so first interaction always shows `dialogue_before`

No code changes required.

## Changes Made

None — already implemented.

## Documentation Updates

None required.
