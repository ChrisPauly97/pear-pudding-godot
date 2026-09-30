# TID-649: Campfire flame frames

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Campfires (WildernessCamp, dungeon campfire chamber) have glow only (`NightLights.gd` L149 'campfire' style, `NightLightMath`). Part of GID-152 (art motion pass).

## Research Notes

- Generate campfire logs + 4-6 flame frames in `generate_sprites.py`; ember spark particles (GPUParticles3D, small, mobile-safe caps like AmbientTouches).
- Attach to `scenes/world/entities/WildernessCamp.gd` and dungeon campfire entity (`game_logic/world/DungeonGen.gd` L119). Cold camp (flag after lesson learned) shows logs only.
- Optionally sync NightLights flicker phase to the frame index.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
