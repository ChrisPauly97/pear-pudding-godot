# TID-079: Screen Shake on Heavy Hits and Death

**Goal:** GID-023
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
