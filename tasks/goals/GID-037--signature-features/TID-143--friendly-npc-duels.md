# TID-143: Friendly NPC Duels with Coin Wagers

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Currently only EnemyNPC entities trigger battles. TownspersonNPC entities exist in named maps but only deliver dialogue. Adding a duelist flag to TownspersonNPC lets any townsperson challenge the player to an optional wager battle — making towns feel like card-playing communities rather than quest dispensers.

## Research Notes

- `scenes/world/entities/TownspersonNPC.gd` — has `npc_id`, `dialogue_key`, and proximity trigger. Add optional `is_duelist: bool` and `wager_coins: int` export vars.
- `scenes/world/entities/EnemyNPC.gd` — reference for how `GameBus.battle_requested` is emitted with an EnemyData resource.
- `autoloads/GameBus.gd` — `battle_requested(enemy_data)` signal already exists; check if it carries a "friendly" flag or if one needs to be added.
- `autoloads/SaveManager.gd` — needs a `defeated_duelists: Array[String]` field (keyed by npc_id) so beaten duelists don't keep offering rematches (or offer reduced-wager rematches after first defeat).
- `game_logic/battle/GameState.gd` — check if a `friendly_duel: bool` flag is needed to suppress "enemy defeated" story logic on win.
- `data/enemies/` — friendly duelist battles use a lightweight EnemyData (no drop pool, just a deck). Consider a `FriendistData` resource or reuse EnemyData with `coin_reward` = wager amount and empty `drop_pool`.
- Named maps to wire up first: `madrian` and `blancogov` have townspeople already.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
