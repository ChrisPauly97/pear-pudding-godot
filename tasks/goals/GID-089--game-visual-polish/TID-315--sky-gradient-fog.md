# TID-315: Atmospheric sky gradient & distance fog

**Goal:** GID-089
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** claude/GID-089--game-visual-polish
**Acquired:** 2026-06-25T00:34:08Z
**Expires:** 2026-06-25T01:04:08Z

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

Replace `BG_COLOR` with `BG_SKY` + `ProceduralSkyMaterial` in `WorldScene._setup_environment()`. Add distance fog to the same environment. Update `DayNightCycle._apply_lighting()` to drive the sky material colors and fog light color instead of the now-removed `background_color`.

## Changes Made

- `scenes/world/WorldScene.gd`: `_setup_environment()` creates `ProceduralSkyMaterial` with initial day colors, wraps it in a `Sky`, sets `env.background_mode = BG_SKY`, enables fog (`fog_enabled`, `fog_density=0.004`, `fog_aerial_perspective=0.3`, `fog_sky_affect=0.7`). Added `_setup_vignette()` call which creates a `CanvasLayer(127)` with a `ColorRect` using an inline `Shader` for edge darkening.
- `scenes/world/DayNightCycle.gd`: Added `_sky_mat: ProceduralSkyMaterial` lazy-getter, updated sky block in `_apply_lighting()` to set `sky_top_color`, `sky_horizon_color`, `ground_horizon_color` on the ProceduralSkyMaterial and update `fog_light_color`.

## Lock

**Session:** none
**Acquired:** —
**Expires:** —
