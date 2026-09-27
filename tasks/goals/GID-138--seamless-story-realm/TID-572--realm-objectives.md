# TID-572: Objectives on the Realm

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** TID-571

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Objective targets become overworld positions; wild story beats get fixed road positions.

## Research Notes

- `ObjectiveTracker.objective_for_map/objective_world_pos`, `StoryCast.spawn_wilderness_camp`,
  `spawn_scout_ambush`, Isfig encounter 2. Compass `CompassRibbon`, `ObjectiveBeacon`, Minimap.

## Plan

Road beats carry a `site` (RealmLayout.STORY_SITES); `ObjectiveTracker.realm_objective`
maps stitched-town tiles and sites into overworld tiles; `objective_for_map` in the
overworld points at an interior's door when the objective is inside. StoryCast places
the camp / Isfig / ambush at their sites and re-checks on every story flag change.

## Changes Made

- `ObjectiveTracker`: `realm_objective()`; `objective_for_map()` resolves overworld
  objectives (negative tiles allowed there) and interior doors; "Leave Madrian" →
  `madrian_south_road` site; camp / fire / Isfig / ambush carry sites; "Travel west to
  Larik" (64,50) and "Defend Marsax Hold" (50,77) moved inside the cropped towns.
- `RealmLayout`: `madrian_south_road` site; marsax_hold crop widened to x=18 so the
  war-camp door (20,50) is stitched.
- `StoryCast`: `spawn_open_world_beats()` (on overworld load and every `story_flag_set`);
  camp/ambush/Isfig spawn at their sites instead of next to the player.
- Tests: whole-story "every objective is pointable in the overworld", town objectives
  inside their crop, stitched tile translation, road-site marking.

## Documentation Updates

- Deferred to TID-573.
