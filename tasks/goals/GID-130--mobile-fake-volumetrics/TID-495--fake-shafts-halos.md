# TID-495: Fake Light Shafts & Night-Light Halos

**Goal:** GID-130
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Stand-ins for volumetric shafts and light scattering: additive, depth-faded geometry that works on Mobile.

## Research Notes

- New module `scenes/world/modules/FakeVolumetrics.gd` (`fake_volumetrics`) created in `_ensure_world_modules()`; shafts are world-anchored quads (grid cells hashed around the player) oriented along the sun, strength from `SunRayMath.strength` × WeatherLook `sun_rays`.
- Halos: extra billboard per `NightLights` rig with a depth-fade soft-edge shader (reuse the depth reconstruct from `night_light_pool.gdshader`).
- Knobs `fake_shafts` (count: 0/6/10) and `light_halos` (bool). `clamp_to_renderer` zeroes `fake_shafts` when real `volumetric_fog` runs.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
