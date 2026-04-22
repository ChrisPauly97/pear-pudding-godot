# TID-079: Screen Shake on Heavy Hits and Death

**Goal:** GID-023
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Heavy hits and hero death feel underpowered without camera feedback. A brief screen shake adds physicality to impactful moments without affecting gameplay.

## Research Notes

- `scenes/battle/BattleScene.gd` — the battle scene root node or a dedicated camera/container is the shake target
- Since the battle scene is a Control (CanvasLayer/Control tree, not a 3D scene), screen shake is implemented by offsetting the root Control's `position` or using a `SubViewportContainer` offset
- Simple shake implementation:
  1. Store original position
  2. Over 0.3s, tween position through a series of small random offsets (±8px)
  3. Return to original position at the end
  4. Use `randf_range(-magnitude, magnitude)` for X and Y each step
- Trigger conditions:
  - Hit of 5+ damage to any entity → magnitude 5px, duration 0.2s
  - Hero death (HP reaches 0) → magnitude 10px, duration 0.35s
- Do NOT shake the world camera (the 3D isometric camera in WorldScene) — only the battle UI
- Cap concurrent shakes: if a shake is already running, skip the new one or extend duration slightly

## Plan

- Add `_is_shaking: bool` to prevent overlapping shakes.
- `_trigger_shake(magnitude, duration)`: captures current `position` as origin, chains `maxi(2, int(duration/0.05))` random-offset tween steps at 0.05s each on self, then returns to origin and clears `_is_shaking`.
- `_check_shake_from_snapshot(snap)`: mirrors `_flash_from_snapshot` diff logic — finds max single-step damage across all entities; triggers hero-death shake (10px/0.35s) if a hero dropped to 0, otherwise heavy-hit shake (5px/0.2s) if max_dmg ≥ 5.
- Call `_check_shake_from_snapshot(snap)` at all 8 existing snapshot sites alongside the float-label and flash calls.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added `_is_shaking: bool = false` member variable.
  - Added `_trigger_shake(magnitude, duration)` — tweens BattleScene root `position` through random offsets then snaps back, then clears `_is_shaking`.
  - Added `_check_shake_from_snapshot(snap)` — computes max HP loss and hero-death flag from snapshot diff; triggers shake accordingly.
  - Added `_check_shake_from_snapshot(snap_XX)` calls at all 8 sites: player minion→minion, player minion→hero, non-targeted spell, targeted spell (card), targeted spell (hero), AI actions, status ticks, auto-spells.

## Documentation Updates

- Updated `docs/agent/battle-system.md` to document the screen shake system.
