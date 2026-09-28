# TID-592: Starter Quest Chain

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-534, TID-590, TID-591

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The core loop for a new player: ~10 short WoW-style quests in the starter zone, each exercising the ability just learned,
with gold rewards that pay for the next training. Sits between story steps `speak_maiteln` and `leave_madrian`.

## Research Notes

- Quest data/registry from TID-533 (`data/quests/*.tres` const-preloaded in `autoloads/QuestRegistry.gd`), accept/turn-in
  from TID-534, progress hooks on kills/collect/talk/explore. QuestLog (`game_logic/quests/QuestLog.gd`) + tracked quest
  drive compass/beacon/minimap (GID-140); NPC "!"/"?" marks via `QuestTracker.gd`.
- Story gating: `game_logic/quests/StoryQuests.gd` STEPS — `speak_maiteln` (done_flag `story_intro_complete`) then
  `leave_madrian` (`chapter1_left_madrian`, site `madrian_south_road`). Add a gating flag (e.g. `starter_chain_complete`)
  so Maiteln sends the player to the outskirts first; either a new StoryQuests step ("Prove yourself on the outskirts")
  or leave_madrian's trigger checks it. Don't edit `docs/human/story.md` — that's TID-596.
- Draft chain (tune in Plan; each ends with "visit your trainer" when a level lands):
  1. Rats in the grain store — kill 3 (auto-attack + Strike) → L2
  2. Patch up — learn Mend, win a fight using it
  3. The hedge-witch's chant — interrupt a caster with Kick (L3)
  4. Raise the fallen — learn minions (L4), win with a minion on board; mention soulbinding capture
  5. First spark — learn spells (L5), finish an enemy with a spell
  6. Maiteln walks with you — companion (L6)
  7. Choose your magic — Skills tab + magic type (L7)
  8. The board by the well — first bounty (L8)
  9. After dark — night hunt spectre (L9)
  10. The old graveyard — gravedigger teaches Dig (L10), dig a burial mound → `starter_chain_complete`, back to Maiteln
- Rewards: gold ≈ next training cost + a little; XP to hit the ladder levels (verify against TID-587 curve); one gear
  reward mid-chain if TID-538 exists, else coins/cards.
- Co-op: quests are per-player; chain works solo first.
- Tests: registry integrity (givers exist on maps, prereqs resolve), a scripted chain walk through the save API
  (accept → progress → turn-in) asserting levels/gold line up with ladder costs.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
