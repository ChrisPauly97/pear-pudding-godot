# TID-521: Wall & Dungeon Detail

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Brick faces flat and dark; no moss, no top highlight, no contact darkening at the base.

## Research Notes

`terrain.gdshader` wall branch (`wall_side_texture`, `wall_top_texture`, `v_cracked`).

## Plan

Wall faces carry a foot→top height fraction in COLOR.r; shader adds moss (base + face-space noise patches, cap tufts), foot contact shadow, lit top edge; lighter grassland wall tint.

## Changes Made

TerrainMath.build_wall_face_mesh face_top colours; terrain.gdshader wall detail block; BiomeDef WALL_TINT[0]; Door label no_depth_test so walls don't clip it.

## Documentation Updates

visual-polish.md (at goal end).
