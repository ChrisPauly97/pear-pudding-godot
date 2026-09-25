# TID-515: Puddles in Low Areas

**Goal:** GID-133
**Type:** agent
**Status:** done
**Depends On:** TID-514

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Puddles are uniform noise patches, not in dips; no reflection or rain ripples; grass pokes through.

## Research Notes

`terrain.gdshader` wet block (`terrain_wetness` global, fbm puddle mask); flat-ground vertex jitter `VERTEX.y += hash2(xz*0.08)*0.12` gives natural dips; grass shaders can share a puddle-mask include.

## Plan

Shared terrain_puddles include (dip from the terrain's own vertex jitter + noise, waterline rises with wetness); terrain sheen/roughness + rain ripple normals; grass sinks in puddles; new terrain_rain global.

## Changes Made

- New `assets/shaders/terrain_puddles.gdshaderinc` (+ .uid); `terrain.gdshader` (`v_dip`, puddle block, ripples); grass includes sink blades.
- `project.godot`: `terrain_rain` global; `DayNightCycle` writes it (`RAIN_PARAM`).
- Tests: `terrain_rain` tracking in `test_atmosphere_math`. Visual check heavy rain; coverage and sheen tuned.

## Documentation Updates

visual-polish.md Puddles in Low Areas section; Rain Wetness heading note.
