# TID-496: HQ Screen Rays & Moon Rays

**Goal:** GID-130
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Mobile High falls back to the Medium screen pass (10 taps). Give it more occlusion taps and a moonlit variant at night.

## Research Notes

- `assets/shaders/sun_rays.gdshader` has `const int SAMPLES = 10` → uniform `samples`.
- `scenes/world/SunRaysFx.gd` computes strength only for the sun; add moon strength (opposite sun, `-sun_h`) in `SunRayMath`, bluish colour.
- Knobs `ray_samples` (0/10/16) and `moon_rays` (off/off/on).

## Plan

Shader loop bound → uniform with MAX_SAMPLES break; SunRayMath.moon_strength; SunRaysFx.set_quality(samples, moon_rays) swaps source/colour/threshold at night; two new knobs.

## Changes Made

- `sun_rays.gdshader`: `samples` uniform (1–24).
- `SunRayMath`: `moon_strength`, `MOON_*` constants.
- `SunRaysFx`: `set_quality`, `is_moon_source`, moon direction/colour/lit threshold; volumetric fog ignores the moon.
- `GraphicsQuality`: `ray_samples` (0/10/16), `moon_rays` (off/off/on). WorldScene forwards them.
- Tests: moon strength curve, moon-ray toggle; GQ monotonic lists. Shaders compile-checked on gl_compatibility under xvfb.

## Documentation Updates

visual-polish.md: knob rows + HQ taps/moon rays bullet.
