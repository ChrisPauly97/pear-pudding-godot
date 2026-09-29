# TID-533: Quest Data & Registry

**Goal:** GID-136
**Type:** agent
**Status:** done
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

Deviation from the research notes: quests are a static GDScript table (`SideQuests.gd`), not `.tres` +
`QuestRegistry` autoload — same pattern as `StoryQuests` / `EnemyRegistry`, no Android preload list, testable
without autoloads.

1. `game_logic/quests/SideQuests.gd`: table + pure rules (offer gating, objective matching, completion, text).
2. `autoloads/save_manager/SaveQuests.gd` + `quests_active` / `quests_completed` fields.
3. GameBus quest signals; progress hooks for kill / flag / learn.
4. QuestLog lists active side quests (kind `side`) so compass, minimap, Journal pick them up (covers most of TID-535).
5. Tests + docs.

## Changes Made

- New `game_logic/quests/SideQuests.gd` (table with first quest `rats_in_grain`, giver `madrian:baker` — the NPC
  itself is placed by TID-534).
- New `autoloads/save_manager/SaveQuests.gd`; `SaveManager`: `quests` module, `quests_active` / `quests_completed`
  fields (+ `PERSISTED_FIELDS`, reset in `new_game`), `active_quests()` passes side quests to QuestLog,
  `set_story_flag` → `quests.progress_event("flag")`, `learn_ability` → `progress_event("learn")` and now emits
  `coins_changed` (it silently deducted coins before).
- `GameBus`: `quest_accepted/progressed/ready/turned_in/abandoned`.
- `BattleVictory`: `quests.progress_event("kill", type)` beside the bounty increments (main + joined enemies).
- `QuestLog`: `side_quest()`, `npc_target()`, `SIDE_PREFIX`, `side` kind colour; `active_quests()` takes `side`.
- Tests: `tests/unit/test_side_quests.gd` (7 tests). Full suite 2794 pass, 0 SCRIPT ERROR; gdlint + unsafe-hits clean.
- BID-064 resolved: TID-535 superseded (GID-140 + this task).

## Documentation Updates

`docs/agent/story-implementation.md`: side-quest row in the QuestLog table + new "Side Quests" section.
