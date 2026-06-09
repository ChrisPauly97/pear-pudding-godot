# TID-179: Mount Framework — Data + Movement

**Goal:** GID-048
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation for mounted travel: MountData registry with one starter mount, owned/active mount tracking in SaveManager, speed multiplier applied to Player movement in the overworld, and GameBus signal to broadcast mount state changes.

## Research Notes

- **Mount data structure:** New file `game_logic/MountRegistry.gd` — a lightweight registry (no `.tres` overhead in v1; cite CLAUDE.md "Map Storage: Native Godot .tres Resources" and "Android: Always preload() .tres Files" — if .tres is added later, use preload pattern + .uid sidecar).
  - One mount in v1: `"stable_horse"` (id, display_name, speed_multiplier: 2.0, price: 750 coins). Cite the GID-046 house price (500 coins) and GID-007 economy as anchor points.
  - Simple const dict registry: `var _mounts := {"stable_horse": {id: "stable_horse", display_name: "Stable Horse", speed_multiplier: 2.0, price: 750}}`.
  - Static getter: `static func get_mount(id: String) -> Dictionary`.

- **SaveManager fields:**
  - Add `owned_mounts: Array[String]` — list of owned mount IDs (v1: just "stable_horse" when purchased).
  - Add `active_mount: String` — currently active mount ID ("" = none).
  - Add `is_mounted: bool` — true only in the overworld (false in battles/interiors); needed for mounted visual state and HUD button feedback.
  - Cite **`autoloads/SaveManager.gd`** CURRENT_SAVE_VERSION (currently 14) — increment to 15.
  - Migration: New `_migrate_v14_to_v15(data)` function (backfill owned_mounts = [], active_mount = "", is_mounted = false). Cite the pattern at lines 300–305 (XP migration) and update `_apply_migrations()` table at line 320+ to add the v14→v15 call.

- **Player speed multiplier:** `Player.gd` currently has `const SPEED: float = 6.0` (line 3). Cite the actual location. In `_physics_process()` (line 50), velocity is set via `velocity.x = dir.x * SPEED` (lines 65–66).
  - Decision: Apply multiplier only in the overworld. Check if player is in the main/infinite world via **`SaveManager.current_map == "main"`** (v14 uses this pattern; cite save-system.md "Field Descriptions" line 68).
  - Add a private method `_get_move_speed() -> float` that returns `SPEED * mount_multiplier` if mounted and in overworld, else `SPEED`. Call this in `_physics_process` instead of the bare constant.
  - Mount multiplier from SaveManager: `var multiplier: float = 1.0; if SaveManager.active_mount != "": var mount := MountRegistry.get_mount(SaveManager.active_mount); if mount.is_empty(): multiplier = mount.get("speed_multiplier", 1.0)`.

- **GameBus signal:** Add `mount_state_changed(mounted: bool, mount_id: String)` to **`autoloads/GameBus.gd`** (analogous to `level_up` at line ~799 in SaveManager.gd). Emit this whenever `is_mounted` or `active_mount` changes.
  - Cite **`docs/agent/signals-and-constants.md`** signal table and add a row documenting this signal.

- **Mounted state transitions:**
  - `summon_mount(mount_id: String)` — called from the HUD button. Check SaveManager.owned_mounts contains mount_id, then set SaveManager.active_mount = mount_id, SaveManager.is_mounted = true, emit signal, mark_dirty().
  - `dismiss_mount()` — called from the HUD button. Set SaveManager.active_mount = "", SaveManager.is_mounted = false, emit signal, mark_dirty(). Player speed reverts to SPEED.

- **Tests:** Headless test file `tests/test_mount_framework.gd`:
  - Test SaveManager round-trip: new_game, own a mount, save, load, verify owned_mounts and active_mount persist.
  - Test speed multiplier math: verify mounted speed = SPEED * 2.0 when in overworld + mounted, SPEED otherwise.
  - Test signal firing: verify mount_state_changed emitted on summon/dismiss.
  - Test migration: create a v14 save data dict, call _apply_migrations, verify v15 fields exist.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
