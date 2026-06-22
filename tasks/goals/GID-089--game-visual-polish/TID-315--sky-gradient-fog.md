# TID-315: Atmospheric sky gradient & distance fog

**Goal:** GID-089
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The `WorldEnvironment` is built in `WorldScene._setup_environment()` (lines ~158–176) with `BG_COLOR` — a single flat background color. `DayNightCycle` updates the background color each frame but it's still a solid wall. This task replaces the flat color background with a procedural `Sky` (using a `ProceduralSkyMaterial`) and adds distance fog so the horizon has depth. Both must respond to `DayNightCycle`'s time-of-day so dawn/dusk/night sky and fog colors change naturally.

## Research Notes

**Current sky setup (WorldScene.gd ~lines 158–176):**
```gdscript
env.background_mode = Environment.BG_COLOR
env.background_color = Color(0.25, 0.5, 0.85)
```
`DayNightCycle._apply_lighting()` updates `env.background_color` to `sky` Color each tick.

**DayNightCycle color transitions (DayNightCycle.gd ~lines 103–115):**
- Day: `Color(0.25, 0.5, 0.85)` (blue)
- Horizon near dawn/dusk: blends to orange `Color(0.7, 0.3, 0.1)`
- Night: `Color(0.02, 0.02, 0.08)`

**ProceduralSkyMaterial approach:**
- `ProceduralSkyMaterial` has `sky_top_color`, `sky_horizon_color`, `ground_horizon_color`, `ground_bottom_color` — all are `Color` uniforms settable at runtime
- No `.tres` file or `.uid` needed — created fully at runtime
- Godot 4 `Environment.background_mode = Environment.BG_SKY` + assign `Sky` resource
- `Sky.sky_material = ProceduralSkyMaterial.new()`

**Fog:**
- `env.fog_enabled = true`
- `env.fog_density` (0.002–0.008 range for world scale)
- `env.fog_aerial_perspective` for sky blending
- `env.fog_light_color` and `env.fog_sky_affect` link fog to sky colors
- Must update fog color alongside sky color in `DayNightCycle`

**DayNightCycle API:**
- `setup(sun, moon, camera, env)` — `env` is already passed in
- `_apply_lighting(weather_tint)` is the place to update sky + fog colors

**Android constraint:** `ProceduralSkyMaterial` is fully supported on mobile GLES3/Vulkan. Fog is a cheap per-fragment effect. No perf concerns.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
