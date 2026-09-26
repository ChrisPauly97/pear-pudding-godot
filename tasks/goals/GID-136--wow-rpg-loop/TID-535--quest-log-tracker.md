# TID-535: Quest Log & On-Screen Tracker

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** TID-533

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Track objectives WoW-style: a quest log screen and a compact tracker on the HUD; compass points at tracked objectives.

## Research Notes

- Bounties: `game_logic/BountyGen.gd` (deterministic daily 3 bounties: defeat type / defeat in biome / open chests);
  save module `autoloads/save_manager/SaveBounties.gd` (`accept_bounty`, `increment_bounty_progress(type, match)`,
  `claim_bounty`); UI `scenes/ui/BountyBoardScene.gd`; `bounty_board` npc_type in
  `scenes/world/modules/NpcInteractions.gd` (match at L16). Progress hooks are where quests should also hook.
- Objective pointing: `game_logic/ObjectiveTracker.gd` (`objective_for_map`, `objective_world_pos`) feeds
  `scenes/ui/CompassRibbon.gd` and the in-world beacon — currently story-flag only.
- Save fields: add to `SaveManager.PERSISTED_FIELDS` (+ var); feature API as a RefCounted module under
  `autoloads/save_manager/` built in `SaveManager._init` (pattern: SaveBounties).
- UI: new `scenes/ui/QuestLogScene.gd` (BaseOverlay subclass, UiUtil factories, viewport-relative sizes); entry via
  PartyPanel or HUD action registry (`_world_hud.register_action`, never bare `_hud.add_child`).
- Tracker: up to 3 tracked quests + active bounties, e.g. "Ghouls slain 2/4". Extend ObjectiveTracker to return the
  tracked quest objective when present (story objective stays a fallback) — compass test `test_compass_bearing`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
