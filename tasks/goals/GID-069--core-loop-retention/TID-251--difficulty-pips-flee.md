# TID-251: Enemy Difficulty Pips in World + Flee Option in Battle

**Goal:** GID-069
**Type:** agent
**Status:** done
**Depends On:** TID-250

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Enemies auto-engage on proximity with no visible indication of how strong they are, and once a battle starts there is no way out except winning or losing. New players walk blind into elite enemies, lose, and hit the (pre-TID-250) dead-end defeat flow. Two fixes: show each enemy's difficulty tier in the world before engagement, and add a **Flee** option to the battle pause menu that returns to the world without rewards.

## Research Notes

- **Difficulty data:** `EnemyRegistry.get_difficulty_tier(enemy_type)` already exists (used for drop tiers in `SceneManager._on_battle_won`, SceneManager.gd:260). Tiers are ints (1–4; bosses treated as 4).
- **Enemy world entity:** `scenes/world/entities/EnemyNPC.gd` / `EnemyNPC.tscn` — Sprite3D-based, wander/track/engage AI (see `docs/agent/enemies-and-npcs.md`). `engage()` at line 73 emits `GameBus.enemy_engaged`. Difficulty display: a small `Label3D` or row of skull pips (Label3D with "💀" repeated, or a Sprite3D strip) positioned above the sprite. Respect the Sprite3D floor-clipping guidance in CLAUDE.md (`position.y` formula); billboard the label.
- **Boss flag:** enemy data dictionaries carry `is_boss` (`pending_battle_enemy_data.get("is_boss")`). Bosses should get a distinct marker (e.g. 4 pips + color).
- **Flee — battle side:** `BattleScene.gd` already has a pause overlay (`_toggle_pause` / `_show_pause_overlay`, BattleScene.gd:473-490, added TID-088) containing settings access and a menu button (`_menu_btn` at line 101 calls `SceneManager.go_to_menu()`). Add a "Flee" button to the pause overlay. Flee flow: emit a new `GameBus.battle_fled` signal (declare in `autoloads/GameBus.gd` — note BID-006: declared-but-unused signals are a known smell, so wire it fully) → SceneManager handler frees the battle overlay, clears pending battle + pending battle state, calls `_restore_world()` — i.e. the loss path minus GameOverScene minus stats, sharing the world-restore plumbing TID-250 establishes.
- **No exploit:** fleeing grants nothing (no XP/coins/cards) and does NOT mark the enemy defeated (`mark_enemy_defeated` not called). The enemy survives in the world.
- **Grace period:** reuse the `EnemyNPC` engage-cooldown mechanic from TID-250 so the fled enemy doesn't instantly re-engage; ~3s and/or require the player to leave engage range once.
- **Boss battles:** decide whether bosses are flee-able. Recommendation: yes (consistency, and bosses guard progress anyway); if a specific story fight must be mandatory, gate on `is_boss` later.
- **Battle pause/resume persistence (GID-034, `docs/agent/battle-system.md`):** fleeing must call `clear_pending_battle_state()` so a stale mid-battle snapshot is not resumed.
- **Mobile parity:** pause overlay buttons already touch-sized; match them.

## Plan

1. Add `signal battle_fled` to GameBus.
2. In `EnemyNPC.init_from_data()`: call `_add_difficulty_pip(etype)` to add a Label3D showing ◆ pips (1–4) or "★ BOSS" in color-coded style.
3. In `BattleScene._show_pause_overlay()`: add a "Flee Battle" button that calls `_on_flee_pressed()` which unpauses, frees pause overlay, and emits `GameBus.battle_fled`.
4. In `SceneManager`: connect `GameBus.battle_fled` → `_on_battle_fled()` which clears pending battle/state, saves, frees battle overlay, and calls `_restore_world()`.

## Changes Made

- `autoloads/GameBus.gd`: added `signal battle_fled`.
- `scenes/world/entities/EnemyNPC.gd`: added `_add_difficulty_pip()` which places a billboard Label3D above each enemy showing difficulty tier pips (or boss marker). Added `_process()` with engage cooldown tick.
- `scenes/battle/BattleScene.gd`: added "Flee Battle" button to pause overlay; added `_on_flee_pressed()`.
- `autoloads/SceneManager.gd`: connected `battle_fled` in `_ready()`; added `_on_battle_fled()` handler.

## Documentation Updates

Updated docs/agent/enemies-and-npcs.md and docs/agent/battle-system.md (part of final doc pass).
