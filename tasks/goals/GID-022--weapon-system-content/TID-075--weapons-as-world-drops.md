# TID-075: Weapons as Chest and Boss Drop Rewards

**Goal:** GID-022
**Type:** agent
**Status:** done
**Depends On:** TID-073

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Weapons need to be discoverable in the world. This task adds weapon drops to chest loot and boss rewards so players encounter them through gameplay rather than only buying from the shop.

## Research Notes

- `scenes/world/entities/Chest.gd` — handles chest opening; currently drops cards; extend to optionally drop a weapon
- Chest weapon drop: low probability (e.g. 15% chance), random selection from WeaponRegistry excluding starter_dagger and any weapon already owned
- `scenes/battle/BattleScene.gd` — handles post-battle rewards; boss battles (is_boss=true) should guarantee a weapon drop from the boss's drop_pool (if drop_pool includes weapon IDs)
- `autoloads/SaveManager.gd` — add weapon to `SaveManager.owned_weapons` on drop; mark dirty; show notification to player
- Distinguish weapon IDs from card IDs in drop pools: use a prefix convention (e.g. weapon IDs always start with a WeaponData field `resource_type: "weapon"`) OR check `WeaponRegistry.has_weapon(id)` first; fall through to CardRegistry if not found
- Show a pickup notification in the HUD (reuse existing interact prompt / dialogue label pattern): "Found: [Weapon Display Name]!"
- Do not add weapons to the SaveManager.owned_weapons if the player already owns that weapon — de-duplicate

## Plan

1. Add `is_boss: bool` to EnemyData; expose via `EnemyRegistry.is_boss()`.
2. Add `WeaponRegistry.has_weapon()` helper for pool filtering.
3. WorldScene chest interaction: 15% chance calls `_maybe_drop_weapon_from_chest()` which picks a random weapon not already owned (skipping rusty_dagger) and emits HUD notification.
4. BattleScene `_check_game_over`: if enemy is_boss, build a weapon_pool from the drop_pool (weapon IDs only) or fall back to all unowned weapons; pass weapon_reward_id to `_show_victory_overlay`.
5. `_show_victory_overlay`: show weapon reward line and pass `weapon_reward` in `battle_won` signal.
6. SceneManager `_on_battle_won`: call `save_manager.add_weapon()` for weapon_reward.

## Changes Made

- `data/EnemyData.gd` — added `is_boss: bool = false`
- `autoloads/EnemyRegistry.gd` — added `is_boss(type_id) -> bool`
- `autoloads/WeaponRegistry.gd` — added `has_weapon(id) -> bool`
- `scenes/world/WorldScene.gd` — preloaded WeaponRegistry/WeaponData; added `_maybe_drop_weapon_from_chest()` (15% chance, excludes rusty_dagger and owned weapons, emits HUD message)
- `scenes/battle/BattleScene.gd` — boss weapon drop in `_check_game_over`; `_show_victory_overlay` accepts `weapon_reward_id`, shows it in overlay, passes it in `battle_won` signal
- `autoloads/SceneManager.gd` — handles `weapon_reward` key in `_on_battle_won`

## Documentation Updates

None — weapon system docs from GID-014 cover the framework; drops are a content extension.
