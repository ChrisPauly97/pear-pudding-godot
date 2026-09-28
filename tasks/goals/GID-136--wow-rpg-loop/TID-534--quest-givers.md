# TID-534: Quest-Giver NPCs & First Madrian Chain

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** TID-533

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Towns need NPCs with asks. Show ! / ? markers, accept + turn-in dialogue, and ship a first 4–6 quest chain in Madrian.

## Research Notes

- NPC dispatch: `scenes/world/modules/NpcInteractions.gd`; NPC entities in named maps (`assets/maps/*.tres`, see
  `docs/agent/named-maps-and-dungeons.md`); dialogue is single-line-per-state (spec) — use a simple accept/decline
  prompt via `WorldScene._build_prompt`.
- Markers: billboard/label above NPC via `SpriteRegistry.make_name_label()`; yellow ! available, grey ! low level,
  yellow ? ready to turn in.
- Interaction order: new entries in `WorldScene.INTERACT_PRIORITY` if a new entity type (test_interact_priority).
- Story content: don't edit `docs/human/story.md`; quest text lives in quest `.tres`. Keep side quests consistent
  with Chapter 1/2 tone.

## Plan

1. Quest panel in `NpcInteractions` ahead of the npc_type dispatch (hand-in > offer), "Other business" fallthrough.
2. `talk` objective progress on every NPC interaction.
3. Side-quest overhead marks (? / ! / grey !) through `QuestLog.npc_mark` + `SaveQuests.npc_state`.
4. Place the first giver (Hilda the Baker) with a reusable map-NPC script.
5. Chain content: the "first Madrian chain" is delivered by GID-141 / TID-592 (townspeople chain) — this task ships the
   mechanism plus the first quest only.

## Changes Made

- `scenes/world/modules/NpcInteractions.gd`: `interact()` → talk progress + `show_quest_panel()`; old body is now
  `interact_service()`; `_quest_panel()`, `reward_text()`.
- `autoloads/save_manager/SaveQuests.gd`: `npc_state()`.
- `game_logic/quests/QuestLog.gd`: `npc_mark(..., side)`; `side_upcoming` colour.
- `scenes/world/modules/QuestTracker.gd`: passes side state to marks; `on_side_quest_ready()` toast.
- `scenes/world/WorldScene.gd`: `quest_*` signals refresh the tracker.
- `assets/maps/madrian.tres`: `hilda_baker` (50,38); `game_logic/quests/SideQuests.gd` giver id updated.
- New `scripts/add_map_npc.py`.
- Tests: 3 more in `test_side_quests.gd`; `test_named_map_npcs` Madrian count 14 → 15. Suite 2797 pass, smokes clean,
  gdlint + unsafe-hits clean.

## Documentation Updates

`docs/agent/story-implementation.md` Side Quests: givers, marks, NPC placement script.
