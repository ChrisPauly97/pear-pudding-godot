# TID-075: Weapons as Chest and Boss Drop Rewards

**Goal:** GID-022
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
