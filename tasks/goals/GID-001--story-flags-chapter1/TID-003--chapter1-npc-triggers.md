# TID-003: Wire Chapter 1 NPC Story Triggers Across All 5 Maps

**Goal:** GID-001
**Type:** agent
**Status:** pending
**Depends On:** TID-002

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With flag storage (TID-001) and flag-gated dialogue (TID-002) in place, this task updates the five Chapter 1 map `.txt` files so that key NPCs use the `FLAG:` syntax and the interaction code sets the correct flags on first contact.

## Research Notes

**Source of truth:** `docs/human/story.md` — NPC positions, dialogue text, and flag names all come from there. Never invent dialogue; copy it verbatim.

**Key story NPCs to wire:**

| Map | NPC | Position | Flag to set | Before dialogue | After dialogue |
|---|---|---|---|---|---|
| madrian | Maiteln | x=45, z=36 | `story_intro_complete` | "I am a wizard of old. If you come with me you will never have to worry about your master again and I will take you on an adventure. My name is Maiteln. Will you come with me?" | "Come, we must make haste before your master notices we are gone." |
| farsyth_mansion | Lord Farsyth | x=49, z=20 | `chapter1_warned_farsyth` | "The Martarquas tribe rising again? By the gods, this is dire news. I shall send word to Lords Marsax, Ramtorous and Temlar at once. You must warn King Eldar in Blancogov!" | "Safe travels, Maiteln. Warn King Eldar swiftly." |
| blancogov_temple | King Eldar | x=42, z=15 | `chapter1_temple_council` | "Maiteln! We are glad you came so swiftly. The council is assembling. The Martarquas threat must be answered together." | "The council has heard the prophecy. We act at dawn." |

**Map files to update** (`assets/maps/*.txt` entity sections — appended after the tile grid):
- `madrian.txt`: change Maiteln NPC line to FLAG syntax; verify Master NPC is present
- `farsyth_mansion.txt`: change Lord Farsyth to FLAG syntax
- `blancogov_temple.txt`: change King Eldar to FLAG syntax; also add Scargroth and Queen lines (static, from story.md)
- `maykalene.txt`: add Townsperson, Innkeeper, and Mansion guard lines (static, from story.md)
- `blancogov.txt`: add Gate guard and City dweller lines (static, from story.md)

**Flag-setting on interact:**
- When the player presses E on a story NPC, `WorldScene` calls `npc.get_dialogue()` and shows it.
- Need to also call `SceneManager.save_manager.set_story_flag(flag_key)` when the interaction fires — only if `flag_key != ""`.
- The interaction code lives in `scenes/world/WorldScene.gd` — find the section that handles NPC interact and add the flag-set call.
- Check `WorldScene.gd` for the interact handler before modifying.

**`chapter1_left_madrian` flag:**
- Set when the player walks through the exit door in madrian. Door traversal goes through `SceneManager.enter_map()` / `exit_map()`. The cleanest hook is in `WorldScene` on door activate: if `current_map == "madrian"` and target is not a sub-map, set the flag.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
