# TID-495: Fake Light Shafts & Night-Light Halos

**Goal:** GID-130
**Type:** agent
**Status:** done
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

New FakeVolumetrics world module with pooled shaft quads on hashed world cells; halo quad per NightLights rig; two knobs; clamp stand-ins off where real volumetric fog runs.

## Changes Made

- New `scenes/world/modules/FakeVolumetrics.gd` (+ WorldScene field/const/`_ensure_world_modules` line).
- New shaders `fake_light_shaft.gdshader`, `light_halo.gdshader` (+ .uid).
- `AtmosphereMath`: `shaft_anchors`, `shaft_axis`, cell hash.
- `NightLights`: halo per rig, `halo_count()`.
- `GraphicsQuality`: `fake_shafts` (0/6/10), `light_halos` (off/on/on), `FAKE_VOLUMETRIC` clamp.
- Tests: anchors/axis in `test_atmosphere_math`; clamp test in `test_graphics_quality`. Shaders compile-checked on gl_compatibility.

## Documentation Updates

visual-polish.md: knob rows, clamp note, Fake Volumetrics section. CLAUDE.md module table: FakeVolumetrics row, AmbientTouches mist.
