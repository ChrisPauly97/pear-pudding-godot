# TID-524: Streams & Ponds

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No water bodies in the infinite world; minimap already shows blue ley lines.

## Research Notes

TerrainMath tiles, puddle sheen in `terrain_puddles.gdshaderinc`.

## Plan

Visual wadeable streams (noise band) + ponds (noise blobs) via new WaterMath, baked per vertex into UV2.y; shader draws water on level grass; grass/props kept out; footstep splashes while wading.

## Changes Made

game_logic/world/WaterMath.gd (+test_water_math); TerrainMath.build_terrain_mesh water_field → UV2.y; ChunkRenderer bakes water, filters grass centres and props; terrain.gdshader v_water dip + water surface; AmbientTouches wading splashes.

## Documentation Updates

visual-polish.md (at goal end).
