# TID-651: Horse trot cycle

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`mount_horse.png` is static; mounted movement slides. Part of GID-152 (art motion pass).

## Research Notes

- `horse` quadruped rig in `generate_characters.py` (32×32, saddle at `Player._SADDLE_OFFSET_PX`). Add 4-frame trot; saddle point must move with bob — expose per-frame saddle y offsets (table in `game_logic`) so the rider tracks.
- Mount visuals: `scenes/world/modules/Mounts.gd`, `Player.gd` (mount sprite, flip_h offset negation note in CLAUDE.md). Play trot when moving, idle when still. Depth-offset rule for rider-over-horse (CLAUDE.md 'Rider invisible while mounted').

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
