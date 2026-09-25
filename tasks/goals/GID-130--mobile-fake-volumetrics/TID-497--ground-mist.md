# TID-497: Ground Mist Particles

**Goal:** GID-130
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rolling low mist at night/dawn in grassland, forest and mountains — soft billboard puffs, cheap at particle_scale.

## Research Notes

- `game_logic/AmbientParticles.gd` factories (shared static meshes/materials) + pure `*_level` rules; `scenes/world/modules/AmbientTouches.gd` fades emitters via `amount_ratio` every 0.5 s.
- Biome ids: 0 grasslands, 1 forest, 2 desert, 3 scorched, 4 mountains.
- Knob `ground_mist` (off/on/on).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
