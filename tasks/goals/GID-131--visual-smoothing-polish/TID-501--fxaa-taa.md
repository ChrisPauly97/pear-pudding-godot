# TID-501: FXAA / TAA Edge Smoothing

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

MSAA misses alpha-cut sprite edges and shader-drawn edges.

## Research Notes

`GraphicsQuality.apply()` writes viewport MSAA. Add `screen_space_aa` (Viewport.SCREEN_SPACE_AA_FXAA; all renderers) and `taa` (Forward+ only → FORWARD_PLUS_ONLY).

## Plan

Two knobs applied to the viewport in GraphicsQuality.apply(); taa joins FORWARD_PLUS_ONLY.

## Changes Made

- `GraphicsQuality`: `fxaa` (off/on/on), `taa` (off/off/on, Forward+ only); `apply()` writes `screen_space_aa` / `use_taa`.
- Tests: `test_edge_smoothing_applied_to_viewport`; monotonic list.

## Documentation Updates

visual-polish.md: knob rows, FORWARD_PLUS_ONLY list.
