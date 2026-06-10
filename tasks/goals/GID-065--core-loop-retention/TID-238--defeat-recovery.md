# TID-238: Defeat Recovery — Retry Battle & Respawn-in-World

**Goal:** GID-065
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Losing a battle currently destroys the play session: `SceneManager._on_battle_lost()` frees `_saved_world_scene` entirely and switches to `GameOverScene`, whose only button returns to the main menu. Getting back into the game requires Continue plus a full world reload (chunks, entities, player position). This is the single biggest retention leak — every loss costs ~4 steps and a reload. The fix: keep the detached world scene alive on loss and offer **Retry Battle** and **Respawn** on the defeat screen alongside Return to Menu.

## Research Notes

- **Loss path:** `autoloads/SceneManager.gd:310` `_on_battle_lost()` — clears pending battle, frees `_battle_overlay`, **frees `_saved_world_scene`** (lines ~322-324), then `change_scene_to_packed(_gameover_scene_packed)` and `_state = State.GAME_OVER`.
- **Win path for contrast:** `_on_battle_won()` (SceneManager.gd:253) frees the battle overlay then calls `_restore_world()` (SceneManager.gd:246) which re-adds `_saved_world_scene` to the root and sets it as current scene. Respawn should reuse `_restore_world()`.
- **Battle start:** `_on_enemy_engaged(enemy_data)` (SceneManager.gd:226) — guards deck size ≥ `IsoConst.DECK_MIN`, stores `_current_battle_enemy_id`, calls `save_manager.set_pending_battle(enemy_data)`, detaches the world scene, instantiates `_battle_scene_packed` with `enemy_data`, promotes it to current scene. **Retry** = re-run the instantiate-battle portion with the same `enemy_data` (keep `pending_battle_enemy_data` alive on loss instead of clearing it — currently `_on_battle_lost` calls `clear_pending_battle()`).
- **GameOverScene:** `scenes/ui/GameOverScene.gd` — 17 lines, label + one button calling `SceneManager.go_to_menu()`. The defeat screen can stay an overlay instead of a full scene change so the world node reference survives (a full `change_scene_to_packed` while holding a detached world node is what forces the free today). Consider: keep `_state = State.GAME_OVER` but present the defeat UI as a CanvasLayer overlay like the battle pause overlay (`BattleScene.gd:473-490`).
- **Respawn semantics:** restore world at current player position. The defeated enemy NPC is still alive in the world and may instantly re-engage — TID-239 adds the grace mechanic; for this task, on respawn move the enemy's wander target away or apply a short engage cooldown on the specific `EnemyNPC` (engage path: `scenes/world/entities/EnemyNPC.gd:73` `engage()` → `GameBus.enemy_engaged.emit(edata)`). A simple `engage_cooldown: float` on EnemyNPC ticked in `_process` is enough.
- **Battle pause/resume persistence (GID-034):** `save_manager.clear_pending_battle_state()` is called on both win and loss — keep clearing battle *state* on loss (retry starts a fresh battle), but retain `pending_battle_enemy_data` until the player chooses Menu/Respawn.
- **Session stats:** `session_stats["battles_lost"]` increment stays as-is.
- **Mobile parity:** buttons sized via viewport-relative fractions (CLAUDE.md), all touch-operable.
- **Tests:** headless tests live in `tests/`, run via `godot --headless --path . -s tests/runner.gd`. Add coverage for the SceneManager state transitions (loss → retry → battle; loss → respawn → world) where testable without rendering.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
