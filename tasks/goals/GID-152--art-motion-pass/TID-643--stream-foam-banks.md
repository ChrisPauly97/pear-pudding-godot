# TID-643: Stream foam and bank dressing

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** TID-642

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Streams have a flat one-texel shoreline only; add foam and pond dressing. Part of GID-152 (art motion pass).

## Research Notes

- Shader water block in `terrain.gdshader`: add foam pixels at shoreline (depth band 0) and where flow speed is high (narrows), animated along `v_flow`; blink with existing `blink` hash.
- Pond props: reeds / lily pads as new prop keys drawn in `tools/generate_sprites.py` (palette from `tools/pixel_palette.py`), registered via `SpriteRegistry.prop_variants()` preloads. ChunkRenderer `_compute_prop_positions` currently skips wet tiles (`WaterMath.wet_at` → continue); add a water-edge scatter pass for reeds (bank) and lily pads (pond only, flow == 0).
- New PNGs need `.import` via headless import; no `.uid` needed for png.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
