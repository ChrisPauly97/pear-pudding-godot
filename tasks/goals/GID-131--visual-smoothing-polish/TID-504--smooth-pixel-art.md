# TID-504: Smooth Pixel-Art Sprite Filtering

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Nearest-filtered sprites at non-integer scale shimmer/jag as the camera moves.

## Research Notes

`SpriteRegistry` sets `TEXTURE_FILTER_NEAREST` + `ALPHA_CUT_OPAQUE_PREPASS` (depth-sorted, see CLAUDE.md mount learning). Options: linear-with-mipmaps filter, or a fat-pixel shader.

## Plan

Custom sprite shader ruled out (texture not auto-bound to material_override). Fixed the camera pixel snap (was 2 px steps) via new PixelSnap helper and pixel-snap the player sprites.

## Changes Made

- New `game_logic/PixelSnap.gd`.
- `WorldScene._snap_to_pixel` uses it with `_camera.size` (bug: old code snapped to 2-pixel steps); calls `Player.snap_visuals_to_pixels` each frame.
- `Player`: pose/offset fields, `snap_visuals_to_pixels`.
- Tests: new `test_pixel_snap.gd`.

## Documentation Updates

camera-and-player.md: Pixel Snapping section.
