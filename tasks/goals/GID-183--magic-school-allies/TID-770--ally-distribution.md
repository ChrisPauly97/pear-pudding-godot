# TID-770: Distribution: drop pools, vendors, packs

**Goal:** GID-183
**Type:** agent
**Status:** pending
**Depends On:** TID-768, TID-769

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New Allies must reach players: thematic drops, shops and packs.

## Research Notes

- Drop pools: `autoloads/EnemyRegistry.gd` per-type `drop_pool` (forest/bog types → verdant Allies; scorched/rift-touched types → rift Allies). Keep `test_enemy_school_profiles` passing.
- Packs: `game_logic/PackDefs.gd` (docs/agent/card-packs.md). Vendors: merchant stock + vendor magic-type preferences (GID-180 TID-746, docs/agent/inventory-and-deck.md).
- Soulbind/signature cards: optional — only if an enemy's signature theme clearly fits.
- Balance bands must still pass (enemy decks unchanged; only drops).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
