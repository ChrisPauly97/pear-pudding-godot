# TID-015: Award Coins on Enemy Defeat

**Goal:** GID-007
**Type:** agent
**Status:** done
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

1. Add `coin_reward: int` export field to `data/EnemyData.gd` (default 5).
2. Set `coin_reward` in all four `.tres` files: undead_basic=5, undead_horde=8, ghoul_pack=12, undead_elite=20.
3. Add `EnemyRegistry.get_coin_reward(type_id) -> int` static method.
4. In `SceneManager._on_battle_won()`, read `save_manager.pending_battle_enemy_data["enemy_type"]` before clearing, look up coin reward, call `save_manager.add_coins()`.

## Changes Made

- `data/EnemyData.gd` — added `@export var coin_reward: int = 5`
- `data/enemies/undead_basic.tres` — set `coin_reward = 5`
- `data/enemies/undead_horde.tres` — set `coin_reward = 8`
- `data/enemies/ghoul_pack.tres` — set `coin_reward = 12`
- `data/enemies/undead_elite.tres` — set `coin_reward = 20`
- `autoloads/EnemyRegistry.gd` — added `get_coin_reward(type_id) -> int` static method
- `autoloads/SceneManager.gd` — added `EnemyRegistry` preload; in `_on_battle_won()`, reads `pending_battle_enemy_data["enemy_type"]` before clearing and calls `save_manager.add_coins(EnemyRegistry.get_coin_reward(enemy_type))`

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` — added coin reward amounts to enemy type table
