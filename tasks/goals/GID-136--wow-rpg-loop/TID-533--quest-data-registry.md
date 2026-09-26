# TID-533: Quest Data & Registry

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

WoW-style quests: NPCs give quests with tracked objectives and rewards. Build the data + save foundation.

## Research Notes

- Bounties: `game_logic/BountyGen.gd` (deterministic daily 3 bounties: defeat type / defeat in biome / open chests);
  save module `autoloads/save_manager/SaveBounties.gd` (`accept_bounty`, `increment_bounty_progress(type, match)`,
  `claim_bounty`); UI `scenes/ui/BountyBoardScene.gd`; `bounty_board` npc_type in
  `scenes/world/modules/NpcInteractions.gd` (match at L16). Progress hooks are where quests should also hook.
- Objective pointing: `game_logic/ObjectiveTracker.gd` (`objective_for_map`, `objective_world_pos`) feeds
  `scenes/ui/CompassRibbon.gd` and the in-world beacon — currently story-flag only.
- Save fields: add to `SaveManager.PERSISTED_FIELDS` (+ var); feature API as a RefCounted module under
  `autoloads/save_manager/` built in `SaveManager._init` (pattern: SaveBounties).
- New `data/QuestData.gd` Resource (id, title, giver_npc, turn_in_npc, objectives[{type: kill|collect|talk|explore,
  target, count, map?, tx?, tz?}], prereq_quests, min_level, rewards {xp, coins, gear_choices[], cards[]}), `.tres`
  files under `data/quests/` with `.uid` sidecars, **const-preloaded** in `autoloads/QuestRegistry.gd` (Android rule).
- Save: `quests_active`, `quests_completed` fields + `autoloads/save_manager/SaveQuests.gd` module (accept, progress,
  complete, turn_in). Emit GameBus signals (quest_accepted/progressed/completed) — keep literal `.emit()` calls.
- Tests: registry integrity (giver NPC exists on a map, prereqs resolve), save round-trip.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
