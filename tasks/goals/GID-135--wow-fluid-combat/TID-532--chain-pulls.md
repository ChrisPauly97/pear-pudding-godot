# TID-532: Chain Pulls — Keep Momentum Between Fights

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-528, TID-531

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With fights in-world, nearby enemies can join or immediately follow, like pulling multiple mobs in WoW.

## Research Notes

- Enemy AI and engage: `scenes/world/EnemyNPC.gd` (wander/track/engage), `GameBus.enemy_engaged`,
  `SceneManager._on_enemy_engaged`. Finders `_find_nearby_*` stay on WorldScene (test_interact_priority).
- Options: (a) an aggro'd enemy within radius joins as a reinforcement wave mid-battle (adds to its board);
  (b) back-to-back: on victory, a tracking enemy in range engages instantly with no camera reset. Start with (b).
- Keep per-instance enemy ids unique (see Spire learnings) and `defeated_enemies` semantics.
- Interacts with TID-541 (pack encounters).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
