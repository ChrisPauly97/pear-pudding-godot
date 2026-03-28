# TID-015: Award Coins on Enemy Defeat

**Goal:** GID-007
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When the player wins a battle, `GameBus.battle_won` is emitted and `SceneManager._on_battle_won()` handles cleanup. Currently no coins are awarded. This task wires a coin reward into that flow.

## Research Notes

**Relevant files:**
- `autoloads/SceneManager.gd` — `_on_battle_won()` is the insertion point; it calls `mark_enemy_defeated()` and triggers the battle reward flow
- `autoloads/SaveManager.gd` — `add_coins(amount: int)` already exists; emits `coins_changed`
- `resources/enemies/` — EnemyData resources each have an `id` field; coin reward can be keyed to enemy type or a new `coin_reward: int` field on EnemyData
- `autoloads/EnemyRegistry.gd` — provides `get_enemy_data(type)` for looking up EnemyData at battle time

**Approach:**
1. Add `coin_reward: int` field to `EnemyData` resource (default 5, scale up by type: undead_basic=5, undead_horde=8, ghoul_pack=12, undead_elite=20).
2. In `SceneManager._on_battle_won()`, look up the active enemy's type via EnemyRegistry and call `SaveManager.add_coins(enemy_data.coin_reward)`.
3. The HUD coin label already listens to `SaveManager.coins_changed` so it will update automatically.

**No new UI needed** — existing coin HUD handles display.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
