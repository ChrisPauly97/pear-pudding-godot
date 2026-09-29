# TID-605: Graveyard Dressing

**Goal:** GID-143
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-066: graveyard is town brick walls + mounds.

## Research Notes

- Generate headstone variants, low iron fence segment, crypt facade props with generate_sprites.py conventions.
- Place as props (see how `NamedMapProps` / prop instancing places static sprites; `docs/agent/visual-polish.md` GPU-instanced props).
- Replace the graveyard fence wall tiles in `madrian.tres` (local 8..18, 47..56) with fence props + keep collision (tiles as WALL but render low? check TerrainMath wall rendering); sealed crypt keeps real walls (Phase needs them).

## Plan

Generate headstones (3), iron fence segment, crypt door in generate_sprites.py; graveyard fence walls → open ground + fence billboards; headstone rows; crypt door facade; spawned once by StarterCamps.

## Changes Made

- `tools/generate_sprites.py`: `headstone()`, `iron_fence()`, `crypt_door()`; 5 new `assets/textures/props/` PNGs
  (existing props regenerate identically).
- `madrian.tres`: graveyard ring wall tiles → grass. `StarterZone.graveyard_props()`, `GRAVEYARD_LOCAL_RECT`.
- `SpriteRegistry.graveyard_prop()`. `StarterCamps._build_scenery()`, `scenery_count()`.
- Test: `test_starter_zone.test_graveyard_dressing`. Verified in an xvfb capture.

## Documentation Updates

`starter-zone-and-training.md` graveyard dressing.
