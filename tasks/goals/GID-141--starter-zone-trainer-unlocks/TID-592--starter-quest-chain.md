# TID-592: Starter Quest Chain

**Goal:** GID-141
**Type:** agent
**Status:** done
**Depends On:** TID-534, TID-590, TID-591

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The core loop for a new player: short WoW-style quests from **townspeople** in Madrian and its outskirts, each exercising
the ability just learned, with gold rewards that pay for the next training. User (2026-09-28): Maiteln is not in town at
the start — he only shows up once several townspeople quests are done, and then says we need to leave.

## Research Notes

- Quest data/registry from TID-533 (`data/quests/*.tres` const-preloaded in `autoloads/QuestRegistry.gd`), accept/turn-in
  from TID-534, progress hooks on kills/collect/talk/explore. QuestLog (`game_logic/quests/QuestLog.gd`) + tracked quest
  drive compass/beacon/minimap (GID-140); NPC "!"/"?" marks via `QuestTracker.gd`.
- **Maiteln's arrival:** today Maiteln is an authored NPC in `assets/maps/madrian.tres` (~L86, dialogue "I am a wizard of
  old…"), and `StoryQuests.STEPS[0]` `speak_maiteln` (done_flag `story_intro_complete`, madrian 45,36) is the first
  objective. Change: add flag `town_quests_done` (set on turning in the last town quest); hide the Maiteln NPC until it is
  set (named-map NPC visibility gate — check how NPCs with `flag_key`/story gating spawn, `ChunkRenderer._spawn_entities`
  / `WorldMap` npc directives), and add a StoryQuests step before `speak_maiteln` (e.g. "Help the townsfolk of Madrian",
  done_flag `town_quests_done`) so compass/journal have an objective from minute one. `StoryCast.maiteln_should_be_present()`
  (follower) already waits for `story_intro_complete` — no change. `CompanionRegistry` unlocks Maiteln on the same flag.
- Draft chain (tune in Plan):
  - Town phase, Maiteln absent (L1→~L5), givers are townspeople (baker, guard, herbalist, smith, sexton…):
    1. Rats in the grain store — kill 3 (auto-attack + Strike) → L2, "visit the Combat Trainer"
    2. Bruised and battered — learn Mend, win a fight using it
    3. The hedge-witch's chant — interrupt a caster with Kick (L3)
    4. Raise the fallen — learn minions (L4), win with a minion on board; mention soulbinding capture
    5. First spark — learn spells (L5), finish an enemy with a spell → `town_quests_done`
  - Maiteln arrives (`speak_maiteln`): he teaches companion (L6) and magic type / Skills tab (L7), then `leave_madrian`.
  - L8–L12 unlocks (bounties, night hunts, Dig, Phase) are taught by trainers the player passes on the Chapter 1 road or
    back in Madrian; give each one a short optional side quest in the outskirts (bounty board by the well, spectre after
    dark, the old graveyard for Dig, a haunted ruin wall for Phase).
- Rewards: gold ≈ next training cost + a little; XP to hit the ladder levels (verify against TID-587 curve); one gear
  reward mid-chain if TID-538 exists, else coins/cards.
- Co-op: quests are per-player; chain works solo first. Co-op joiners who skip the town phase must still see Maiteln
  if the host has him (check `CoopSession` story-flag sync).
- Tests: registry integrity (givers exist on maps, prereqs resolve), a scripted chain walk through the save API
  (accept → progress → turn-in) asserting levels/gold line up with ladder costs, Maiteln hidden before `town_quests_done`.

## Plan

1. `MapNpc.show_flag_key` (+ WorldMap, ChunkRenderer skip, live spawn in StoryCast) → Maiteln waits on
   `town_quests_done`; new first story step `help_townsfolk`; migration marks existing saves done.
2. Five townsfolk givers + five town quests (L1→6), seven optional L6–12 quests from townsfolk / Bounty Master /
   Gravedigger, each asking the player to learn and then use the latest unlock at the next camp.
3. Progress hooks for skill use, digging, chest opening.
4. Pacing test on the real XP curve (found the curve's L2 is 200 XP, not 50 as its comment said).

## Changes Made

- `game_logic/quests/SideQuests.gd`: 12 quests; `open` objective type.
- `game_logic/quests/StoryQuests.gd`: `help_townsfolk` step.
- `game_logic/world/resources/MapNpc.gd` `show_flag_key`; `WorldMap.gd` parse/serialize; `ChunkRenderer.gd` skip;
  `StoryCast.spawn_flag_shown_npcs()`.
- `assets/maps/madrian.tres`: `wenna_herbalist`, `brother_aldo`, `old_tam`, `ivy_chandler`; Maiteln `show_flag_key`.
- Hooks: `BattleSkillBar.gd` (use_skill), `BurialMound.gd` (dig), `ChestLoot.gd` (open).
- `SaveMigrations._m44`: sets `town_quests_done` for existing saves. `SaveManager.xp_for_level` comment corrected.
- Tests: `test_side_quests.gd` +2 (chain pacing walk, learn objectives vs ladder levels), kill targets updated;
  `test_objective_tracker.gd` / `test_quest_log.gd` for the new first step. Suite green, smokes clean, lint clean.

## Documentation Updates

`starter-zone-and-training.md` quest-chain section + XP pacing fix; `story-implementation.md` objective types, hooks, starter chain.
