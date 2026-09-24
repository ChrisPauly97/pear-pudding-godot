# TID-488: Sun Rays (Volumetric on High, Post-Process Fallback)

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** TID-484

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Visible light shafts at dawn/dusk and through fog. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- High + Forward+: `env.volumetric_fog_enabled`, low density, `sun.light_volumetric_fog_energy`; tune so it doesn't haze midday (compare with glow notes in `_setup_environment`).
- Medium (Mobile): screen-space radial blur 'god rays' shader on a CanvasLayer ColorRect (pattern: vignette in `WorldScene._setup_vignette`, layer 127). Sample `hint_screen_texture`, march toward the sun's screen position (`Camera3D.unproject_position(camera.position - sun.basis.z * far)`), fade out when sun is off-screen or below horizon. Strength peaks near the horizon.
- Low: off. New `.gdshader` needs `.uid`.
- Watch the per-frame cost on mobile: use few samples (≤16) and half-resolution if possible.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

1. Pure module `game_logic/SunRayMath.gd` (static): `strength(sun_h, weather_mult)` — fades in over
   sun height 0–0.06, out over 0.2–0.6 (zero at midday and night); `screen_direction(sun_dir, cam_basis)`
   and `source_uv(dir, aspect)`. The iso camera is **orthographic**, so the research note's
   `unproject_position(camera.position - sun.basis.z * far)` lands arbitrarily far off-screen: instead
   project the sun direction onto the camera plane and put a virtual source just past the screen edge
   it points to (dawn → right, dusk → left, higher sun → top). `volumetric_density(strength)`.
2. WeatherLook key `sun_rays` (CLEAR 1.0; light weather dampens, heavy_rain/blizzard 0).
3. `assets/shaders/sun_rays.gdshader` (+ `.uid`): canvas_item, `blend_add`, `hint_screen_texture`;
   angular noise shafts × distance falloff × 10-tap occlusion march toward the source (≤16 taps).
4. `scenes/world/SunRaysFx.gd` (Node, not a module — owns its own CanvasLayer at layer 0, under the HUD):
   `setup(camera, sun, moon, env, dnc)`, `set_mode(SUN_RAYS_*)`, 10 Hz `refresh()` from time + blended
   weather look. SCREEN: shader params, layer hidden below MIN_STRENGTH (no cost at midday/night/storms).
   VOLUMETRIC: sun-only volumetric fog (ambient/GI/sky inject 0, anisotropy 0.7, moon + fill-light fog
   energy 0), density scaled by strength and fog switched off at zero; screen pass at 0.6 weight.
5. `GraphicsQuality` High `volumetric_fog` → true (Forward+ clamp unchanged). WorldScene: create
   SunRaysFx after the DayNightCycle, re-call `set_mode` from `apply_graphics_quality` (~10 lines,
   stays under the 2180 ceiling).
6. Tests `tests/unit/test_sun_rays.gd`; docs visual-polish.md; task/goal/index status.

## Changes Made

- `game_logic/SunRayMath.gd` (new, pure/static): ray `strength` curve (low sun only, × weather), `screen_direction` (sun direction projected onto the ortho camera plane), `source_uv` (virtual source 1.2× past the exit edge), `volumetric_density` (0.018 × strength, 0 below 0.01).
- `assets/shaders/sun_rays.gdshader` + `.uid` (new): additive canvas shader — drifting angular value-noise shafts, `exp` falloff from the source, 10-tap occlusion march over the screen texture. Verified it compiles and renders under xvfb (GL Compatibility; Vulkan unavailable in the container).
- `scenes/world/SunRaysFx.gd` (new): mode handling (OFF / SCREEN / VOLUMETRIC), 10 Hz refresh from DayNightCycle time + blended weather look, hides its CanvasLayer (layer 0, under the HUD) when strength < 0.01; volumetric mode configures sun-only fog and drives density / enable.
- `game_logic/WeatherLook.gd`: `sun_rays` multiplier key (clear 1.0, rain 0.4, snow 0.5, dust_devil 0.7, ash_fall 0.35, sandstorm 0.2, volcanic 0.1, heavy_rain/blizzard 0.0).
- `game_logic/GraphicsQuality.gd`: High `volumetric_fog` on (still clamped off on Mobile/Compatibility); knob comments point at SunRaysFx.
- `scenes/world/WorldScene.gd` (+10 lines, 2173 < 2180): creates `SunRaysFx` after the DayNightCycle, `apply_graphics_quality()` forwards the `sun_rays` knob live; fill light `light_volumetric_fog_energy = 0`.
- `tests/unit/test_sun_rays.gd` (new, 7 tests).
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, suite 2467 passed / 0 failed with 0 `SCRIPT ERROR`, `world_scene_smoke` exit 0 with 0 `SCRIPT ERROR` (exit-time leak warnings same as baseline).

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet; knob table (`volumetric_fog` High on, `sun_rays` reader); new "Sun Rays" How-It-Works section (strength curve, weather, ortho virtual source, screen pass, volumetric tuning, cost, wiring); Integrations bullet; Asset Requirements note for the new shader.
