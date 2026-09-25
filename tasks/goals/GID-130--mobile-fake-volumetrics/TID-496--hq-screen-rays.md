# TID-496: HQ Screen Rays & Moon Rays

**Goal:** GID-130
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
