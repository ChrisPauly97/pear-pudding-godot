# TID-069: Create 6 New Enemy .tres Files

**Goal:** GID-021
**Type:** agent
**Status:** pending
**Depends On:** TID-068

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Using the deck and drop pool data authored in TID-068, this task creates .tres resource files for the 6 new enemy types and their .uid sidecars.

## Research Notes

- Existing enemy .tres files live in `data/enemies/` — follow their EnemyData schema exactly
- `autoloads/EnemyRegistry.gd` loads all enemies from `data/enemies/` — verify it uses `dir.list_dir_begin()` for auto-discovery; if hardcoded, add new IDs
- Every .tres needs a companion `.uid` file (see CLAUDE.md for generation command)
- EnemyData fields (check `data/enemies/*.tres` for exact field names): id, display_name, coin_reward, deck: Array[String], drop_pool: Array[String]
- The 6 enemies: wraith (grasslands), forest_shade (forest), sand_stalker (desert), scorched_revenant (scorched), mountain_troll (mountains), stone_golem (mountains)
- Do NOT set boss=true on these — stone_golem is high-tier but not a formal boss; TID-070/071 handle actual bosses
- Use the deck compositions from story.md (TID-068 output)

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
