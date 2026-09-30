# TID-647: Tree and plant wind sway

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Trees, ferns, flowers are static; grass already sways with weather wind. Part of GID-152 (art motion pass).

## Research Notes

- Props render as one MultiMeshInstance3D per prop key with a cached material (`ChunkRenderer._prop_visual_cache`, L47-50; positions from `_compute_prop_positions` + `game_logic/world/TreeScatter.gd`).
- New shader `assets/shaders/prop_sway.gdshader` (+ `.uid`): billboard like current material, vertex offset ∝ (UV.y from base)² × wind, phase from instance world position (`MODEL_MATRIX[3]` / `INSTANCE_ID`), stepped in time for pixel look. Reuse globals `grass_wind_scale`, `grass_wind_lean` (registered in `scenes/world/GrassBlades.gd` L108) and `wind_direction`.
- Sprite3D + custom material gotcha (CLAUDE.md): texture must be fed explicitly; keep alpha-cut + depth prepass.
- Rigid props (rock, boulder, ash pile, cactus, headstone) opt out; per-key stiffness table.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
