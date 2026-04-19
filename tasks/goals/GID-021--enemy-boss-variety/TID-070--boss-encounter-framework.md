# TID-070: Boss Encounter Framework

**Goal:** GID-021
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No boss system exists. This task adds a boss flag to EnemyData and changes the battle presentation for boss fights (distinct UI treatment, optional phase-2 mechanic). TID-071 then places actual bosses using this framework.

## Research Notes

- `data/enemies/EnemyData.gd` (or the Resource subclass used for enemies) — add `is_boss: bool` and optionally `phase2_deck: Array[String]` (empty = no phase 2)
- `scenes/battle/BattleScene.gd` — when `is_boss` is true:
  - Show a boss name banner at battle start (Label that fades in/out)
  - Enemy hero HP could be higher (set via enemy data or a `boss_hp: int` field on EnemyData)
  - Phase 2: if `phase2_deck` is non-empty, when enemy HP drops below 50%, swap enemy deck to phase2_deck (discard hand, draw from new deck)
- Boss battles should not drop a random card from drop_pool — they should drop all items in the drop_pool (guaranteed rewards for a hard fight)
- `scenes/world/entities/EnemyNPC.gd` — boss enemies in the world could have a different sprite tint or scale to visually distinguish them; keep this simple (just a modulate color change)
- Follow CLAUDE.md UI sizing for the boss banner

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
