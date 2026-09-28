# TID-600: Rift Entrances in Each Biome

**Goal:** GID-142
**Type:** agent
**Status:** pending
**Depends On:** TID-597, TID-589

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Each rift is entered from its own biome, so rifting in "different biomes with different enemy types" means travelling.

## Research Notes

- Current entrance: a spire door in a town map (`scenes/world/entities/Door.gd` `_is_spire`, purple modulate L32–44) →
  WorldScene panel (~L1900) → `SceneManager.enter_spire()`. Generalise the panel: rift name, best tier, tier picker
  (1..best+1), active quest, Enter/Resume.
- Placement: one portal per biome in the infinite world. Options: deterministic placement per biome near the first
  chunk of that biome from spawn, or attach to existing landmarks (`InfiniteWorldGen.gd` landmarks L18–30, e.g.
  "shattered_spire" for Scorched). Must be findable: add to realm map / minimap (`RealmMapOverlay`, `Minimap.gd`) once
  discovered. The Grasslands rift should be near Madrian (starter zone, TID-591).
- A rift keeper NPC at each portal gives that rift's quests (TID-599); interaction via `INTERACT_PRIORITY`
  (`test_interact_priority`) or `_try_simple_interaction` table.
- Gate on `feat_spire` (GID-141 TID-589): portal visible but "The rift is sealed to you (level 15)" until learned.
- Resuming an active run from another rift's portal: refuse or resume the original — decide in Plan.
- Mobile parity: tap target + interact button.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
