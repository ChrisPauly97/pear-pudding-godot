# TID-581: Quest Model — Story Steps Table & QuestLog

**Goal:** GID-140
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Replace ObjectiveTracker's if-chain with an ordered story steps table (chapter, giver, summary) and add a QuestLog aggregating story, treasure and bounty quests with map targets.

## Research Notes

- `game_logic/ObjectiveTracker.gd` current_objective: most-advanced flag wins; tests in `tests/unit/test_objective_tracker.gd`.
- Treasure: `SaveManager.active_treasure` {site_x, site_z, completed} in overworld tiles.
- Bounties: `SaveManager.active_bounties` entries {id,type,target,count,progress,completed,claimed}; boards are MapNpc npc_type bounty_board in madrian/maykalene/blancogov (`RealmLayout.entities("npcs")`).
- Bounty text lives in `BountyBoardScene._format_bounty_desc` → move to BountyGen.

## Plan

Ordered StoryQuests.STEPS table (same most-advanced-flag semantics); ObjectiveTracker delegates and exposes generic place_on_map/target_world_pos; QuestLog aggregates story/treasure/bounty quests with target lists; tracked_quest save field.

## Changes Made

- New `game_logic/quests/StoryQuests.gd` (steps with chapter, giver, summary, done_flag, place) and `QuestLog.gd` (active_quests, story_quest with post-Chapter-2 'Between Chapters' fallback → bounty boards, tracked, world_pos nearest target, bounty_board_targets).
- `ObjectiveTracker`: if-chain replaced by StoryQuests; `to_realm`, `place_on_map`, `target_world_pos` work for any target dict.
- `BountyGen.describe()` (moved from BountyBoardScene).
- SaveManager: `tracked_quest` persisted field, `set_tracked_quest`, `active_quests()`, `tracked_quest_data()`; GameBus `quest_tracking_changed`.
- Tests: `tests/unit/test_quest_log.gd`.

## Documentation Updates

Covered by TID-585.
