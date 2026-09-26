# TID-534: Quest-Giver NPCs & First Madrian Chain

**Goal:** GID-136
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
