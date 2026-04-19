# TID-071: Add 2 Boss Encounters to Named Maps

**Goal:** GID-021
**Type:** agent
**Status:** pending
**Depends On:** TID-068, TID-070

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Using the boss framework (TID-070) and the human-authored boss data (TID-068), this task creates the boss EnemyData .tres files and places them in the correct named maps.

## Research Notes

- Boss placements from story.md (TID-068 output): one mid-story boss and one Chapter 1 end boss
- Create .tres files for each boss in `data/enemies/` with `is_boss = true`; give them higher HP (e.g. 40–50), strong decks, and guaranteed drop pools
- Place bosses in named maps as ENEMY directives in the appropriate .tres MapData:
  - Mid-story boss: likely `farsyth_mansion.tres` or `blancogov.tres` — check story.md for intended placement
  - Chapter 1 end boss: `blancogov_temple.tres`
- Boss enemies in named maps should be flagged so they only spawn once (use `SaveManager.defeated_enemies` — same pattern as regular enemies)
- The boss enemy NPC in the world scene should use `is_boss=true` EnemyData to trigger the boss battle framework in BattleScene
- Add `.uid` sidecars for boss .tres files

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
