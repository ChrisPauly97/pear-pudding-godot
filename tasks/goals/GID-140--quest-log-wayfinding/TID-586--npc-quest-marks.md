# TID-586: NPC "!" / "?" Quest Marks

**Goal:** GID-140
**Type:** agent
**Status:** done
**Depends On:** TID-585

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User follow-up (2026-09-28): "add the ! ?". WoW-style overhead marks so the player
can see at a glance who to talk to.

## Research Notes

- NPC nodes: `WorldScene._npc_nodes` (id → Node3D), spawn data `_active_npc_data` ({x, z, npc_type}).
- Name tags are Label3D children (`SpriteRegistry.make_name_label`, height ~1.6–2.2);
  `ObjectiveBeacon` arrow bobs at `ARROW_Y` ± `BOB_AMPLITUDE`.
- Bounty offers: `SaveManager.bounties.get_offered_bounties()` (daily refresh); max 3 active.

## Plan

Pure rule `QuestLog.npc_mark(npc, story_tile, turn_in, offers)`; QuestTracker applies
it to every spawned NPC on each quest refresh, creating/updating/removing a
`QuestMark` Label3D only when the mark changes.

## Changes Made

- `QuestLog.npc_mark()`, `has_bounty_turn_in()`.
- `QuestTracker._refresh_npc_marks()` / `_set_mark()` / `_mark_height()`:
  gold "!" over the NPC standing on the story step's tile (±1); bounty board violet
  "?" when a contract is ready to claim, "!" when offers are up and you have room.
- Tests: `test_quest_log` (mark rules), `world_scene_smoke` (Maiteln wears a "!" on a new game).

## Documentation Updates

`docs/agent/story-implementation.md` (Quest Log section).
