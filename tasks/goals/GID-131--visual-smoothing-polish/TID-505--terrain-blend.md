# TID-505: Softer Terrain Tile Blending

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Ground shows a visible tile grid of lighter/darker diamonds.

## Research Notes

`assets/shaders/terrain.gdshader`, mesh built by `TerrainMath`/`ChunkRenderer`. Add world-space noise detail and soften per-tile colour steps in the fragment shader.

## Plan

Per-vertex macro noise (reusing the dead v_d0/v_d1 varyings), hard-switch anti-tiling via rotated UV in noise blobs, noisy soft path edges.

## Changes Made

- `assets/shaders/terrain.gdshader`: macro brightness/dryness variation, `uv_grass` anti-tiling, `path_t` soft edges. Visual check on gl_compatibility.

## Documentation Updates

terrain-rendering.md: Softening the tile grid subsection.
