# TID-506: Grass Shading Pass

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Grass reads as dark spiky clumps.

## Research Notes

`grass_blade.gdshader`, `grass_cluster.gdshader` (unshaded, alpha_to_coverage, global `grass_day_tint`).

## Plan

Smooth gradient + terrain-matched colours + per-blade jitter in both grass shaders.

## Changes Made

- `grass_blade.gdshader`, `grass_cluster.gdshader`: new colour defaults, smoothstep gradient, root-hash jitter. Visual check on gl_compatibility (default and zoomed).

## Documentation Updates

terrain-rendering.md: Grass colour subsection.
