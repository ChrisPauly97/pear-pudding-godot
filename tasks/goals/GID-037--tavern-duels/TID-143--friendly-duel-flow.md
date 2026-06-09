# TID-143: Friendly Duel Battle Flow

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles currently assume the opponent is a hostile enemy: winning sets defeat flags, drops cards, and removes the enemy from the world. A friendly duel needs a parallel mode — same battle overlay, but the stakes are a coin wager and nothing in the world changes. This task builds the mode flag and wager resolution; TID-144 attaches it to NPCs.

## Research Notes

- `game_logic/battle/GameState.gd` — add `friendly_duel: bool` (default false) and `wager_coins: int`. When true, suppress story-defeat side effects on battle end.
- `autoloads/GameBus.gd` — `battle_requested(enemy_data)` signal exists. Either add an optional `friendly: bool` arg or a new `duel_requested(enemy_data, wager)` signal — prefer the new signal to avoid touching every existing emitter.
- `scenes/battle/BattleScene.gd` — battle-end handler is where win/loss currently triggers `coin_reward` and drop pools (GID-002, GID-007 patterns). In duel mode: win → player gains `wager_coins`; loss → player loses `wager_coins` (floor at 0).
- `autoloads/SaveManager.gd` — coins field exists from GID-007 (check exact name, likely `coins`). No new fields in this task.
- **Duelist decks:** Reuse `EnemyData` with empty `drop_pool` and `coin_reward = 0` (wager handled separately by duel mode). Create 2–3 duelist EnemyData `.tres` files in `data/enemies/` with `.uid` sidecars, e.g. `duelist_novice`, `duelist_adept`. Follow the preload-constant rule in `EnemyRegistry.gd`.
- **Loss handling:** A duel loss must NOT trigger GameOverScene — the player just loses the wager and returns to the world. Check how `BattleScene` routes hero death; branch on `friendly_duel`.
- `docs/agent/battle-system.md` — document the duel mode flag and end-of-battle branching.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
